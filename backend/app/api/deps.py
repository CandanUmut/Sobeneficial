# backend/app/api/v1/deps.py
from typing import Optional
from fastapi import Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from ..db.session import async_session
from ..middleware.auth import get_current_user_id

async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session

async def require_user_id(user_id: Optional[str] = Depends(get_current_user_id)) -> str:
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return user_id

# --- NEW: alias for older routes that import `auth_user` ---
async def auth_user(user_id: str = Depends(require_user_id)) -> str:
    return user_id
