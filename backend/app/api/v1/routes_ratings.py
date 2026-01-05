from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id

router = APIRouter()

@router.post("", response_model=dict)
async def rate(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Expects: {"entity":"rfh|question|content|project|event", "entity_id":"uuid", "stars": 1..5}
    Upsert by (entity, entity_id, rater_id).
    """
    entity = payload.get("entity")
    entity_id = payload.get("entity_id")
    stars = payload.get("stars")
    if not entity or not entity_id or not isinstance(stars, int) or not (1 <= stars <= 5):
        return {"ok": False, "detail": "bad payload"}

    await db.execute(
        text("""
            insert into public.ratings (entity, entity_id, rater_id, stars)
            values (:e, :id, :uid, :s)
            on conflict (entity, entity_id, rater_id) do update set stars = excluded.stars
        """),
        {"e": entity, "id": entity_id, "uid": user_id, "s": stars},
    )
    await db.commit()
    return {"ok": True}
