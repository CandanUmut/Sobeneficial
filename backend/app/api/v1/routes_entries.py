from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.post("", response_model=dict)
async def create_entry(
    body: str,
    images: list[str] | None = None,
    anonymous: bool = False,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    r = await db.execute(
        text("""
          insert into public.entries (author_id, body, images, anonymous)
          values (:uid, :body, coalesce(:imgs, array[]::text[]), :anon)
          returning id
        """),
        {"uid": user_id, "body": body, "imgs": images, "anon": anonymous},
    )
    await db.commit()
    return {"id": str(r.scalar())}

@router.get("", response_model=list[dict])
async def list_entries(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        text("""
          select e.id, e.author_id, e.body, e.images, e.anonymous, e.created_at
          from public.entries e
          where e.visibility='public'
          order by e.created_at desc
          limit 50
        """)
    )
    return [row_to_dict(x) for x in res.fetchall()]
