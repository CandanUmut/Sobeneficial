from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ..deps import get_db                     # fixed relative import (from v1 -> api)
from ...utils.dbhelpers import row_to_dict    # stays the same (api.v1 -> app.utils)

router = APIRouter(prefix="/match", tags=["match"])

@router.get("/{rfh_id}", response_model=list[dict])
async def match_helpers(rfh_id: str, db: AsyncSession = Depends(get_db)):
    rfh = await db.execute(
        text("select tags, language, region from public.rfh_public where id=:id"),
        {"id": rfh_id},
    )
    r = rfh.first()
    if not r:
        raise HTTPException(status_code=404, detail="RFH not found")

    tags = (r._mapping["tags"] or [])
    if not tags:
        res = await db.execute(
            text(
                "select id as helper_id, reputation::float as score "
                "from public.profiles "
                "order by reputation desc limit 10"
            )
        )
        return [row_to_dict(x) for x in res.fetchall()]

    # NOTE: asyncpg handles Python list -> Postgres text[] for :tags.
    res = await db.execute(
        text(
            """
            select id as helper_id,
                   (
                     select count(*)
                     from unnest(offers) t(tag)
                     where t.tag = any(:tags)
                   )::float
                   + reputation / 100.0 as score
            from public.profiles
            where array_length(offers, 1) is not null
            order by score desc
            limit 10
            """
        ),
        {"tags": tags},
    )
    return [row_to_dict(x) for x in res.fetchall()]
