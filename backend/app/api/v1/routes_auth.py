from fastapi import APIRouter, Depends
from ...middleware.auth import get_current_user_id

router = APIRouter()

@router.get("/me")
async def me(user_id: str | None = Depends(get_current_user_id)):
    # In dev without token this returns {"user_id": null}
    return {"user_id": user_id}
