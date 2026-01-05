from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...schemas.profiles import Profile, ProfileUpdate
from ...utils.dbhelpers import row_to_dict
from datetime import date

router = APIRouter()

@router.get("/me", response_model=Profile | dict)
async def get_me(db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    q = await db.execute(text("select * from public.profiles where id=:uid"), {"uid": user_id})
    row = q.first()
    if not row:
        raise HTTPException(404, "Profile not found")
    return row_to_dict(row)

@router.put("/me", response_model=dict)
async def update_me(payload: ProfileUpdate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    fields = {k: v for k, v in payload.model_dump(exclude_none=True).items()}
    if not fields:
        return {"updated": False}
    sets = ", ".join([f"{k}=:{k}" for k in fields.keys()])
    fields["uid"] = user_id
    sql = text(f"update public.profiles set {sets}, updated_at=now() where id=:uid")
    await db.execute(sql, fields)
    await db.commit()
    return {"updated": True}

@router.get("/{id_or_username}", response_model=dict)
async def get_public_profile(
    id_or_username: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    # resolve by id first, then username
    q = await db.execute(text("""
      with prof as (
        select p.*
          from public.profiles p
         where p.id::text = :key
            or p.username = :key
         limit 1
      ),
      stats as (
        select
          (select count(*)::int from public.engagements e
            where e.practitioner_id = (select id from prof) and e.state='completed') as completed_engagements,
          (select coalesce(avg(r.stars)::float,0.0) from public.ratings r
            where r.entity::text='offer'
              and r.entity_id in (select id from public.offers where owner_id=(select id from prof))) as avg_stars,
          (select coalesce(count(*)::int,0) from public.ratings r
            where r.entity::text='offer'
              and r.entity_id in (select id from public.offers where owner_id=(select id from prof))) as ratings_count
      )
      select json_build_object(
        'profile', (select row_to_json(prof.*) from prof),
        'stats',   (select row_to_json(stats.*) from stats),
        'offers',  (select coalesce(json_agg(row_to_json(o.*)), '[]'::json)
                    from public.offer_public o where o.owner_id = (select id from prof))
      )
    """), {"key": id_or_username})
    row = q.first()
    if not row or not row[0]:
        raise HTTPException(404, "Profile not found")
    return row[0]



@router.get("/{id_or_username}", response_model=dict)
async def get_public_profile(
    id_or_username: str,
    include_next_slots: bool = Query(False),
    limit_slots: int = Query(3, ge=0, le=12),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    q = await db.execute(text(f"""
      with prof as (
        select p.*
          from public.profiles p
         where p.id::text = :key
            or p.username = :key
         limit 1
      ),
      stats as (
        select
          (select count(*)::int from public.engagements e
            where e.practitioner_id = (select id from prof) and e.state='completed') as completed_engagements,
          (select coalesce(avg(r.stars)::float,0.0) from public.ratings r
            where r.entity::text='offer'
              and r.entity_id in (select id from public.offers where owner_id=(select id from prof))) as avg_stars,
          (select coalesce(count(*)::int,0) from public.ratings r
            where r.entity::text='offer'
              and r.entity_id in (select id from public.offers where owner_id=(select id from prof))) as ratings_count
      ),
      offers as (
        select o.*
        from public.offer_public o
        where o.owner_id = (select id from prof)
      ),
      offers_with_next as (
        select
          o.*,
          (
            select coalesce(json_agg(json_build_object('start_at', s.start_at, 'end_at', s.end_at)
                                     order by s.start_at)
                            , '[]'::json)
            from (
              select start_at, end_at
              from public.offer_slots s
              where s.offer_id = o.id
                and s.status='open'
                and s.reserved < s.capacity
                and s.start_at >= now()
              order by s.start_at
              limit :limit_slots
            ) s
          ) as next_slots
        from offers o
      )
      select json_build_object(
        'profile', (select row_to_json(prof.*) from prof),
        'stats',   (select row_to_json(stats.*) from stats),
        'offers',  (select coalesce(
                      case when :inc then json_agg(row_to_json(ow.*))
                           else json_agg(row_to_json(o.*))
                      end, '[]'::json)
                    from (select * from offers_with_next) ow
                    full join (select * from offers) o on false)
      )
    """), {"key": id_or_username, "inc": include_next_slots, "limit_slots": limit_slots})
    row = q.first()
    if not row or not row[0]:
      raise HTTPException(404, "Profile not found")
    return row[0]



@router.get("/{id_or_username}/availability.by_day", response_model=list[dict])
async def profile_availability_by_day(
    id_or_username: str,
    from_: date = Query(..., alias="from"),
    to_:   date = Query(..., alias="to"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    sql = text("""
      with prof as (
        select id from public.profiles
         where id::text = :key or username = :key
         limit 1
      )
      select
        (date_trunc('day', s.start_at))::date as day,
        json_agg(
          json_build_object(
            'offer_id', o.id,
            'offer_title', o.title,
            'start_at', s.start_at,
            'end_at', s.end_at,
            'capacity', s.capacity,
            'reserved', s.reserved
          ) order by s.start_at
        ) as slots
      from public.offer_slots s
      join public.offers o on o.id = s.offer_id
      where o.owner_id = (select id from prof)
        and s.status='open'
        and s.reserved < s.capacity
        and s.start_at >= cast(:from as date)
        and s.start_at <  cast(:to as date) + interval '1 day'
      group by 1
      order by 1
    """)
    rows = (await db.execute(sql, {"key": id_or_username, "from": from_.isoformat(), "to": to_.isoformat()})).mappings().all()
    return [{"day": r["day"].isoformat(), "slots": r["slots"] or []} for r in rows]