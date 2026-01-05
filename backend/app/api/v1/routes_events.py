from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...schemas.events import EventCreate
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.post("", response_model=dict)
async def create_event(payload: EventCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    r = await db.execute(text("""
        insert into public.events (host_id, title, description, type, starts_at, ends_at, location, capacity, tags, visibility)
        values (:uid, :title, :description, :type, :starts_at, :ends_at, :location, :capacity, :tags, :visibility)
        returning id
    """), {"uid": user_id, **payload.model_dump()})
    eid = r.scalar()
    await db.commit()
    return {"id": str(eid)}

@router.get("", response_model=list[dict])
async def list_events(db: AsyncSession = Depends(get_db)):
    res = await db.execute(text("select id, host_id, title, type, starts_at, ends_at, location, tags, created_at from public.events order by starts_at asc limit 50"))
    return [row_to_dict(r) for r in res.fetchall()]

@router.post("/{event_id}/enroll", response_model=dict)
async def enroll_event(event_id: str, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    await db.execute(text("""
        insert into public.event_enrollments (event_id, user_id, status)
        values (:eid, :uid, 'going')
        on conflict do nothing
    """), {"eid": event_id, "uid": user_id})
    await db.commit()
    return {"enrolled": True}
