from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from ...api.deps import get_db, require_user_id
from ...schemas.rfh import RFHCreate
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.post("", response_model=dict)
async def create_rfh(
    payload: RFHCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    sql = text("""
        insert into public.rfh (requester_id, title, body, tags, sensitivity, anonymous, region, language)
        values (:uid, :title, :body, :tags, :sensitivity, :anonymous, :region, :language)
        returning id
    """)
    params = {
        "uid": user_id,
        "title": payload.title,
        "body": payload.body,
        "tags": payload.tags,
        "sensitivity": payload.sensitivity,
        "anonymous": payload.anonymous,
        "region": payload.region,
        "language": payload.language,
    }
    r = await db.execute(sql, params)
    new_id = r.scalar()
    await db.commit()
    return {"id": str(new_id)}

@router.get("", response_model=list[dict])
async def list_rfh(
    q: Optional[str] = None,
    tag: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """
    Maskeli public liste (anon ise owner/admin değilse requester_id gizlenir).
    Ayrıca basit metrikler (views/avg_stars/ratings_count) varsa döndürür.
    """
    base = """
        select
          r.id,
          case 
            when r.anonymous and r.requester_id <> auth.uid()
              and not exists (
                select 1 from public.profiles p
                where p.id = auth.uid() and ('admin' = any(p.roles))
              )
            then null
            else r.requester_id
          end as requester_id,
          r.title, r.body, r.tags, r.sensitivity, r.anonymous, r.status,
          r.region, r.language, r.created_at, r.updated_at,
          -- metrics (tablolar yoksa 0 döner)
          coalesce((
            select count(*)::int from public.views v
            where v.entity='rfh' and v.entity_id=r.id
          ), 0) as views,
          coalesce((
            select avg(rt.stars)::float from public.ratings rt
            where rt.entity='rfh' and rt.entity_id=r.id
          ), 0.0) as avg_stars,
          coalesce((
            select count(*)::int from public.ratings rt2
            where rt2.entity='rfh' and rt2.entity_id=r.id
          ), 0) as ratings_count
        from public.rfh r
    """
    conds = []
    args: dict = {}
    if q:
        conds.append("(r.title ilike :q or r.body ilike :q)")
        args["q"] = f"%{q}%"
    if tag:
        conds.append(":t = any(r.tags)")
        args["t"] = tag
    if conds:
        base += " where " + " and ".join(conds)
    base += " order by r.created_at desc limit 50"

    res = await db.execute(text(base), args)
    rows = res.fetchall()
    return [row_to_dict(r) for r in rows]

@router.get("/{rfh_id}", response_model=dict)
async def get_rfh(rfh_id: str, db: AsyncSession = Depends(get_db)):
    """
    Detay: requester_id masking + is_owner bilgisi.
    Metrikler de ekli (varsa).
    """
    res = await db.execute(text("""
        select
          r.id,
          case 
            when r.anonymous and r.requester_id <> auth.uid()
              and not exists (
                select 1 from public.profiles p
                where p.id = auth.uid() and ('admin' = any(p.roles))
              )
            then null
            else r.requester_id
          end as requester_id,
          (r.requester_id = auth.uid()) as is_owner,
          r.title, r.body, r.tags, r.sensitivity, r.anonymous, r.status,
          r.region, r.language, r.created_at, r.updated_at,
          coalesce((
            select count(*)::int from public.views v
            where v.entity='rfh' and v.entity_id=r.id
          ), 0) as views,
          coalesce((
            select avg(rt.stars)::float from public.ratings rt
            where rt.entity='rfh' and rt.entity_id=r.id
          ), 0.0) as avg_stars,
          coalesce((
            select count(*)::int from public.ratings rt2
            where rt2.entity='rfh' and rt2.entity_id=r.id
          ), 0) as ratings_count
        from public.rfh r
        where r.id=:id
    """), {"id": rfh_id})
    row = res.first()
    if not row:
        raise HTTPException(404, "Not found")
    return row_to_dict(row)

@router.delete("/{rfh_id}", status_code=204)
async def delete_rfh(
    rfh_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Sadece owner silebilir. (RLS ile de korunmalı)
    """
    # Sahip mi?
    chk = await db.execute(text("select requester_id from public.rfh where id=:id"), {"id": rfh_id})
    row = chk.first()
    if not row:
        raise HTTPException(404, "Not found")
    if str(row._mapping["requester_id"]) != str(user_id):
        raise HTTPException(403, "Only owner can delete the RFH")

    await db.execute(text("delete from public.rfh where id=:id"), {"id": rfh_id})
    await db.commit()
    return
