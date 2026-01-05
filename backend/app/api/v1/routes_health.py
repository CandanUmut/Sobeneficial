from fastapi import APIRouter
from ...db.session import ping_db

router = APIRouter(tags=["health"])

@router.get("/healthz")
async def healthz():
    try:
        await ping_db()
        return {"status": "ok"}
    except Exception as e:
        return {"status": "db_error", "detail": str(e)}
