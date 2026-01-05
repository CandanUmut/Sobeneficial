# backend/app/api/v1/routes_psm_gifts.py
from __future__ import annotations
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, UUID4
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_db, require_user_id

router = APIRouter()

class GiftCreate(BaseModel):
  units: int = 1
  note: Optional[str] = None
  valid_until: Optional[datetime] = None

# CREATE gift (keeps your existing structure; ensures 'used' starts at 0)
@router.post("/psm/offers/{offer_id}/gifts")
async def create_gift(
  offer_id: UUID4,
  payload: GiftCreate,
  db: AsyncSession = Depends(get_db),
  user_id: str = Depends(require_user_id)
):
  if payload.units <= 0:
    raise HTTPException(400, "units must be > 0")
  r = await db.execute(text("""
    insert into public.offer_gifts (offer_id, sponsor_id, units, used, note, status)
    values (:oid, :uid, :u, 0, :n, 'active')
    returning id
  """), {"oid": str(offer_id), "uid": user_id, "u": payload.units, "n": payload.note})
  new_id = r.scalar()
  await db.commit()
  return {"id": str(new_id)}

# AVAILABLE using (units - used)
@router.get("/psm/offers/{offer_id}/gifts/available")
async def gifts_available(offer_id: UUID4, db: AsyncSession = Depends(get_db)):
  q = text("""
    select coalesce(sum(greatest(units - used, 0)), 0)::int as available
      from public.offer_gifts
     where offer_id = :oid
       and status = 'active'
       and (valid_until is null or valid_until >= now())
  """)
  r = await db.execute(q, {"oid": str(offer_id)})
  return {"available": r.scalar() or 0}
