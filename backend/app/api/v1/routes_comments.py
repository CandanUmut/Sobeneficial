from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.get("", response_model=list[dict])
async def list_comments(
    entity: str = Query(...),
    id: str = Query(..., alias="id"),
    db: AsyncSession = Depends(get_db),
):
    """
    GET /api/comments?entity=rfh&id=<uuid>
    Returns newest first.
    """
    res = await db.execute(
        text("""
            select c.id, c.entity, c.entity_id, c.author_id, c.body, c.created_at,
                   p.username as author_username,
                   p.display_name as author_name,
                   p.avatar_url as author_avatar_url
            from public.comments c
            left join public.profiles p on p.id = c.author_id
            where c.entity = :e and c.entity_id = :id
            order by c.created_at desc
        """),
        {"e": entity, "id": id},
    )
    return [row_to_dict(r) for r in res.fetchall()]

@router.post("", response_model=dict)
async def create_comment(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Expects: {"entity":"rfh", "entity_id":"uuid", "body":"text"}
    """
    entity = payload.get("entity")
    entity_id = payload.get("entity_id")
    body = payload.get("body")
    if not entity or not entity_id or not body:
        return {"ok": False, "detail": "missing fields"}

    r = await db.execute(
        text("""
            insert into public.comments (entity, entity_id, author_id, body)
            values (:e, :id, :uid, :b)
            returning id
        """),
        {"e": entity, "id": entity_id, "uid": user_id, "b": body},
    )
    cid = r.scalar()
    await db.commit()
    return {"ok": True, "id": str(cid)}
