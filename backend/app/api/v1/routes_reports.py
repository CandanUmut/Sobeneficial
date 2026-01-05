from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...schemas.reports import ReportCreate

router = APIRouter()

@router.post("", response_model=dict)
async def create_report(payload: ReportCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    r = await db.execute(text("""
        insert into public.reports (reporter_id, entity, entity_id, reason, severity)
        values (:uid, :entity, :eid, :reason, :severity) returning id
    """), {"uid": user_id, "entity": payload.entity, "eid": payload.entity_id, "reason": payload.reason, "severity": payload.severity})
    rid = r.scalar()
    await db.commit()
    return {"id": str(rid)}
