# backend/app/api/v1/routes_psm_slots.py
from __future__ import annotations
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, UUID4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
# imports – add these / merge with your existing ones

from fastapi import APIRouter, Depends, HTTPException, Query

from ..deps import get_db, auth_user  # adjust import to your project

router = APIRouter()

# --- Pydantic models: let Pydantic parse ISO strings -> datetime objects ---
class SlotCreate(BaseModel):
    start_at: datetime         # accepts "2025-09-23T05:00:00Z" etc, becomes aware dt
    end_at: datetime
    capacity: Optional[int] = 1
    note: Optional[str] = None

class SlotOut(BaseModel):
    id: UUID4
    offer_id: UUID4
    start_at: datetime
    end_at: datetime
    capacity: int
    reserved: int
    status: str
    note: str | None = None

# --- Create slot ---
@router.post("/psm/offers/{offer_id}/slots")
async def create_slot(
    offer_id: UUID4,
    payload: SlotCreate,
    db: AsyncSession = Depends(get_db),
    user = Depends(auth_user),
):
    # (Optional) authorization: ensure user owns the offer_id
    # ...

    # Use named binds + pass real datetimes
    q = text("""
        insert into public.offer_slots (offer_id, start_at, end_at, capacity, note)
        values (:offer_id, :start_at, :end_at, coalesce(:capacity,1), coalesce(:note,''))
        returning id
    """)
    params = {
        "offer_id": str(offer_id),
        "start_at": payload.start_at,   # <-- datetime object
        "end_at": payload.end_at,       # <-- datetime object
        "capacity": payload.capacity or 1,
        "note": payload.note or "",
    }
    try:
        r = await db.execute(q, params)
        new_id = r.scalar_one()
        await db.commit()
        return {"id": str(new_id)}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"create_slot failed: {e}")

# --- List slots for an offer ---
@router.get("/psm/offers/{offer_id}/slots", response_model=List[SlotOut])
async def list_slots(
    offer_id: UUID4,
    db: AsyncSession = Depends(get_db),
    user = Depends(auth_user),
):
    q = text("""
        select id, offer_id, start_at, end_at, capacity, reserved, status, note
        from public.offer_slots
        where offer_id = :offer_id
        order by start_at asc
    """)
    r = await db.execute(q, {"offer_id": str(offer_id)})
    rows = r.mappings().all()
    return [dict(row) for row in rows]

# --- Cancel a slot (soft cancel) ---
@router.delete("/psm/offers/{offer_id}/slots/{slot_id}")
async def cancel_slot(
    offer_id: UUID4,
    slot_id: UUID4,
    db: AsyncSession = Depends(get_db),
    user = Depends(auth_user),
):
    q = text("""
        update public.offer_slots
           set status = 'cancelled',
               updated_at = now()
         where id = :slot_id
           and offer_id = :offer_id
        returning id
    """)
    r = await db.execute(q, {"slot_id": str(slot_id), "offer_id": str(offer_id)})
    row = r.first()
    if not row:
        raise HTTPException(status_code=404, detail="slot not found")
    await db.commit()
    return {"ok": True}


# --- LIST SLOTS BY DATE RANGE (open by default) ---
from datetime import date, time, timedelta, timezone

@router.get("/psm/offers/{offer_id}/slots", response_model=list[dict])
async def list_slots_by_range(
    offer_id: UUID4,
    from_: date | None = Query(None, alias="from"),
    to_:   date | None = Query(None, alias="to"),
    only_open: bool = True,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(auth_user),
):
    where = ["s.offer_id = :oid"]
    args = {"oid": str(offer_id)}
    if only_open:
        where.append("s.status = 'open'")
    if from_:
        where.append("s.start_at >= :from_at")
        args["from_at"] = datetime.combine(from_, time.min, tzinfo=timezone.utc)
    if to_:
        where.append("s.start_at < :to_at")
        args["to_at"]   = datetime.combine(to_ + timedelta(days=1), time.min, tzinfo=timezone.utc)

    q = text(f"""
      select s.id, s.offer_id, s.start_at, s.end_at, s.capacity, s.reserved, s.status, s.note
        from public.offer_slots s
       where {" and ".join(where)}
       order by s.start_at asc
    """)
    rows = (await db.execute(q, args)).mappings().all()
    return [dict(r) for r in rows]

# --- NEXT SLOTS SNIPPET FOR ONE OFFER ---
@router.get("/psm/offers/{offer_id}/next_slots", response_model=list[dict])
async def next_slots(
    offer_id: UUID4,
    limit: int = 6,
    db: AsyncSession = Depends(get_db),
):
    q = text("""
      select id, start_at, end_at, capacity, reserved
        from public.offer_slots
       where offer_id = :oid
         and status = 'open'
         and reserved < capacity
         and start_at > now()
       order by start_at asc
       limit :lim
    """)
    r = await db.execute(q, {"oid": str(offer_id), "lim": max(1, min(limit, 12))})
    return [dict(x) for x in r.mappings().all()]

# --- OPTIONAL: PATCH alias for cancel (keeps DELETE working) ---
from fastapi import Query

@router.patch("/psm/offers/{offer_id}/slots/{slot_id}")
async def cancel_slot_patch(
    offer_id: UUID4,
    slot_id: UUID4,
    db: AsyncSession = Depends(get_db),
    user: str = Depends(auth_user)
):
    q = text("""
        update public.offer_slots
           set status = 'cancelled', updated_at = now()
         where id = :sid and offer_id = :oid
        returning id
    """)
    r = await db.execute(q, {"sid": str(slot_id), "oid": str(offer_id)})
    if not r.first():
        raise HTTPException(404, "slot not found")
    await db.commit()
    return {"ok": True}
