from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.get("", response_model=list[dict])
async def my_notifications(db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    res = await db.execute(text("select id, type, payload, read_at, created_at from public.notifications where user_id=:uid order by created_at desc limit 100"), {"uid": user_id})
    return [row_to_dict(r) for r in res.fetchall()]
