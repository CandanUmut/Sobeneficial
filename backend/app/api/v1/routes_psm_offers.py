# app/api/v1/routes_psm_offers.py
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import json
from datetime import date
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter(prefix="/psm", tags=["psm"])

# ---- Create/Update offer (owner) - optional but handy for demo ----
@router.post("/offers", response_model=dict)
async def create_offer(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Body:
    {
      "type":"legal|psychological|career|other",
      "title":"..",
      "description":"..",
      "tags":["family-law","immigration"],
      "fee_type":"free|paid|sliding",
      "languages":["en","tr"],
      "region":"TR-Istanbul",
      "availability": {...}   # json
    }
    """
    r = await db.execute(
        text("""
            insert into public.offers
              (owner_id, type, title, description, tags, fee_type, languages, region, availability)
            values
              (:owner, :type, :title, :desc, :tags, :fee, :langs, :region, CAST(:availability AS jsonb))
            returning id
        """),
        {
            "owner": user_id,
            "type": payload.get("type"),
            "title": payload.get("title"),
            "desc": payload.get("description"),
            "tags": payload.get("tags") or [],
            "fee": payload.get("fee_type"),
            "langs": payload.get("languages") or [],
            "region": payload.get("region"),
            # keep dumps to avoid asyncpg encode pitfalls on text() binds
            "availability": json.dumps(payload.get("availability") or {}),
        },
    )

    oid = r.scalar()
    await db.commit()
    return {"id": str(oid)}

# ---- Browse offers (PSM-01) ----
@router.get("/offers", response_model=dict)
async def list_offers(
    q: Optional[str] = None,
    type: Optional[str] = None,
    tag: Optional[str] = None,
    fee: Optional[str] = None,
    region: Optional[str] = None,
    lang: Optional[str] = None,
    sort: str = Query("new", pattern="^(new|rating|popular)$"),
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db),
):
    page = max(1, page)
    page_size = max(1, min(page_size, 50))
    offset = (page - 1) * page_size

    base = """
      from public.offer_public o
      left join public.profiles p on p.id = o.owner_id
      where 1=1
    """
    args = {}
    if q:
        base += " and (o.title ilike :q or o.description ilike :q)"
        args["q"] = f"%{q}%"
    if type:
        base += " and o.type = :type"
        args["type"] = type
    if tag:
        base += " and :tag = any(o.tags)"
        args["tag"] = tag
    if fee:
        base += " and o.fee_type = :fee"
        args["fee"] = fee
    if region:
        base += " and o.region = :region"
        args["region"] = region
    if lang:
        base += " and :lang = any(o.languages)"
        args["lang"] = lang

    sort_sql = "o.created_at desc"
    if sort == "rating":
        sort_sql = "o.avg_stars desc, o.ratings_count desc nulls last"
    elif sort == "popular":
        sort_sql = "o.views desc, o.ratings_count desc nulls last"

    count_sql = f"select count(*) {base}"
    rows_sql = f"""
      select
        o.id, o.type, o.title, o.description, o.tags, o.fee_type,
        o.languages, o.region, o.availability,
        o.avg_stars, o.ratings_count, o.views,
        o.owner_id, coalesce(p.username, '') as owner_username, coalesce(p.avatar_url, '') as owner_avatar_url,
        o.created_at
      {base}
      order by {sort_sql}
      limit :limit offset :offset
    """
    args_rows = {**args, "limit": page_size, "offset": offset}

    total = (await db.execute(text(count_sql), args)).scalar() or 0
    res = await db.execute(text(rows_sql), args_rows)
    items = [row_to_dict(r) for r in res.fetchall()]
    return {"items": items, "page": page, "page_size": page_size, "total": int(total)}

@router.get("/offers/{offer_id}", response_model=dict)
async def get_offer(offer_id: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        text("""
            select
              o.*, p.username as owner_username, p.avatar_url as owner_avatar_url
            from public.offer_public o
            left join public.profiles p on p.id = o.owner_id
            where o.id = :id
        """),
        {"id": offer_id},
    )
    row = res.first()
    if not row:
        raise HTTPException(404, "Offer not found")
    return row_to_dict(row)

@router.get("/offers/{offer_id}/gifts/available", response_model=dict)
async def gifts_available(offer_id: str, db: AsyncSession = Depends(get_db)):
    r = await db.execute(
        text("""
          SELECT COALESCE(SUM(units - used), 0) AS available
          FROM public.offer_gifts
          WHERE offer_id = CAST(:oid AS uuid)
            AND status = 'active'
        """),
        {"oid": offer_id},
    )
    row = r.first()
    return {"available": int(row[0] or 0)}


def _build_where(q: Optional[str], type_: Optional[str], tag: Optional[str],
                 fee_type: Optional[str], region: Optional[str], lang: Optional[str]):
    clauses = ["true"]  # so we can safely "AND ..."
    params = {}

    if q:
        clauses.append("(o.title ILIKE :q OR o.description ILIKE :q)")
        params["q"] = f"%{q}%"

    if type_:
        clauses.append("o.type = :type")
        params["type"] = type_

    if fee_type:
        clauses.append("o.fee_type = :fee_type")
        params["fee_type"] = fee_type

    if region:
        clauses.append("o.region = :region")
        params["region"] = region

    if tag:
        clauses.append(":tag = ANY(o.tags)")
        params["tag"] = tag

    if lang:
        clauses.append(":lang = ANY(o.languages)")
        params["lang"] = lang

    return " AND ".join(clauses), params


def _order_clause(sort: str) -> str:
    s = (sort or "new").lower()
    if s == "rating":
        return "o.avg_stars DESC NULLS LAST, o.ratings_count DESC, o.created_at DESC"
    if s == "popular":
        return "o.views DESC NULLS LAST, o.created_at DESC"
    # default
    return "o.created_at DESC"

# AFTER  ✅ (remove the extra /psm because router already has prefix="/psm")
@router.get("/offers.with_next_slots", response_model=dict)
async def offers_with_next_slots(
    q: Optional[str] = None,
    type: Optional[str] = Query(None, alias="type"),
    tag: Optional[str] = None,
    fee_type: Optional[str] = None,
    region: Optional[str] = None,
    lang: Optional[str] = None,
    page: int = 1,
    page_size: int = Query(20, ge=1, le=100),
    sort: str = "new",
    limit_slots: int = Query(3, ge=0, le=12),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns { items: [offer_public + next_slots[]], total, page, page_size }
    next_slots are open upcoming slots limited by `limit_slots`.
    """
    where, params = _build_where(q, type, tag, fee_type, region, lang)
    params.update({
        "limit": page_size,
        "offset": (max(page, 1) - 1) * page_size,
        "limit_slots": limit_slots,
    })

    # total count
    cnt_sql = text(f"SELECT COUNT(*) FROM public.offer_public o WHERE {where}")
    total = (await db.execute(cnt_sql, params)).scalar() or 0

    order = _order_clause(sort)

    # items with LATERAL subquery for next slots
    items_sql = text(f"""
        SELECT
          o.*,
          ns.next_slots
        FROM public.offer_public o
        LEFT JOIN LATERAL (
          SELECT COALESCE(
            json_agg(
              json_build_object('start_at', s.start_at, 'end_at', s.end_at)
              ORDER BY s.start_at
            ),
            '[]'::json
          ) AS next_slots
          FROM (
            SELECT start_at, end_at
            FROM public.offer_slots s
            WHERE s.offer_id = o.id
              AND s.status = 'open'
              AND s.reserved < s.capacity
              AND s.start_at >= now()
            ORDER BY s.start_at
            LIMIT :limit_slots
          ) s
        ) ns ON TRUE
        WHERE {where}
        ORDER BY {order}
        LIMIT :limit OFFSET :offset
    """)

    rows = (await db.execute(items_sql, params)).mappings().all()
    items = [dict(r) for r in rows]

    return {
        "items": items,
        "total": int(total),
        "page": page,
        "page_size": page_size,
    }



@router.get("/offers/availability.by_day", response_model=list[dict])
async def offers_availability_by_day(
    from_: date = Query(..., alias="from"),
    to_:   date = Query(..., alias="to"),
    q: Optional[str] = None,
    type: Optional[str] = Query(None, alias="type"),
    tag: Optional[str] = None,
    fee_type: Optional[str] = None,
    region: Optional[str] = None,
    lang: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    """
    Returns list[
      { day: 'YYYY-MM-DD',
        slots: [ {offer_id, offer_title, owner_id, owner_username, start_at, end_at, capacity, reserved, region} ...]
      }
    ]
    """
    where, params = _build_where(q, type, tag, fee_type, region, lang)
    params.update({"from": from_.isoformat(), "to": to_.isoformat()})
    sql = text(f"""
      WITH base AS (
        SELECT
          (date_trunc('day', s.start_at))::date AS day,
          o.id AS offer_id,
          o.title AS offer_title,
          o.owner_id,
          p.username AS owner_username,
          s.start_at, s.end_at, s.capacity, s.reserved,
          o.region
        FROM public.offer_slots s
        JOIN public.offer_public o ON o.id = s.offer_id
        LEFT JOIN public.profiles p ON p.id = o.owner_id
        WHERE s.status = 'open'
          AND s.reserved < s.capacity
          AND s.start_at >= CAST(:from AS date)
          AND s.start_at <  (CAST(:to AS date) + interval '1 day')
          AND {where}
      )
      SELECT
        day,
        json_agg(
          json_build_object(
            'offer_id', offer_id,
            'offer_title', offer_title,
            'owner_id', owner_id,
            'owner_username', owner_username,
            'start_at', start_at,
            'end_at', end_at,
            'capacity', capacity,
            'reserved', reserved,
            'region', region
          )
          ORDER BY start_at
        ) AS slots
      FROM base
      GROUP BY day
      ORDER BY day
    """)
    rows = (await db.execute(sql, params)).mappings().all()
    return [{"day": r["day"].isoformat(), "slots": r["slots"] or []} for r in rows]