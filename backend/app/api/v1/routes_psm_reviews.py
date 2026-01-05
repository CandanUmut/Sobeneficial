from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, UUID4
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from ...api.deps import get_db, require_user_id

router = APIRouter()


# ---------- Schemas ----------
class ReviewCreate(BaseModel):
    stars: int
    comment: str


# ---------- Helpers ----------
async def _load_engagement_bundle(db: AsyncSession, eng_id: str):
    """
    Returns dict with: {state, offer_id, requester_id}
    """
    q = await db.execute(
        text("""
            select
              e.state,
              r.offer_id,
              e.requester_id
            from public.engagements e
            join public.offer_requests r on r.id = e.request_id
            where e.id = cast(:eid as uuid)
            limit 1
        """),
        {"eid": eng_id},
    )
    row = q.mappings().first()
    return dict(row) if row else None


# ---------- Endpoints ----------

@router.get("/psm/offers/{offer_id}/reviews", response_model=list[dict])
async def list_offer_reviews(
    offer_id: UUID4,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    sql = text("""
        select
          r.stars,
          r.comment,
          r.created_at,
          r.reviewer_id,
          p.username as reviewer_username
        from public.offer_reviews r
        join public.profiles p on p.id = r.reviewer_id
        where r.offer_id = cast(:oid as uuid)
        order by r.created_at desc
        limit :lim offset :off
    """)
    rs = await db.execute(sql, {"oid": str(offer_id), "lim": limit, "off": offset})
    return [dict(x) for x in rs.mappings().all()]


@router.post("/psm/engagements/{eng_id}/reviews", response_model=dict)
async def create_review_for_engagement(
    eng_id: UUID4,
    payload: ReviewCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    # basic validation
    stars = int(payload.stars)
    comment = (payload.comment or "").strip()
    if stars < 1 or stars > 5:
        raise HTTPException(400, "stars must be 1..5")
    if len(comment) == 0:
        raise HTTPException(400, "comment is required")

    # load engagement + offer + requester
    bundle = await _load_engagement_bundle(db, str(eng_id))
    if not bundle:
        raise HTTPException(404, "engagement not found")

    if bundle["state"] != "completed":
        raise HTTPException(409, "only completed engagements can be reviewed")

    # only the requester (beneficiary) can leave a review for now
    if str(user_id) != str(bundle["requester_id"]):
        raise HTTPException(403, "only the requester can review this engagement")

    # insert review (unique on (engagement_id) and (offer_id, reviewer_id))
    try:
        ins = await db.execute(
            text("""
                insert into public.offer_reviews
                    (offer_id, engagement_id, reviewer_id, stars, comment)
                values
                    (cast(:oid as uuid), cast(:eid as uuid), cast(:rid as uuid), :stars, :comment)
                returning id, created_at
            """),
            {
                "oid": str(bundle["offer_id"]),
                "eid": str(eng_id),
                "rid": str(user_id),
                "stars": stars,
                "comment": comment,
            },
        )
        row = ins.mappings().first()
        await db.commit()
    except IntegrityError:
        # already reviewed (unique constraint)
        await db.rollback()
        raise HTTPException(409, "review already exists for this engagement / offer")

    return {
        "id": str(row["id"]),
        "offer_id": str(bundle["offer_id"]),
        "engagement_id": str(eng_id),
        "reviewer_id": str(user_id),
        "stars": stars,
        "comment": comment,
        "created_at": row["created_at"],
    }
