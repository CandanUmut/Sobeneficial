from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id

router = APIRouter()

@router.post("", response_model=dict)
async def add_view(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Expects: {"entity":"rfh|question|content|project|event", "entity_id":"uuid"}
    """
    entity = payload.get("entity")
    entity_id = payload.get("entity_id")
    if not entity or not entity_id:
        return {"ok": False, "detail": "missing entity/entity_id"}

    await db.execute(
        text("""
            insert into public.views (entity, entity_id, viewer_id)
            values (:e, :id, :uid)
        """),
        {"e": entity, "id": entity_id, "uid": user_id},
    )
    await db.commit()
    return {"ok": True}
