from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from ..deps import get_db, require_user_id         # fixed relative import
from ...schemas.content import ContentCreate
from ...utils.dbhelpers import row_to_dict

router = APIRouter(prefix="/content", tags=["content"])


@router.post("", response_model=dict)
async def create_content(payload: ContentCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    csql = text("""
        insert into public.content (author_id, type, title, summary, body, evidence, visibility, sources, region, language)
        values (:uid, :type, :title, :summary, :body, :evidence, :visibility, coalesce(:sources,'[]'::jsonb), :region, :language)
        returning id
    """)
    params = {
        "uid": user_id,
        "type": payload.type, "title": payload.title, "summary": payload.summary, "body": payload.body,
        "evidence": payload.evidence, "visibility": payload.visibility, "sources": payload.sources,
        "region": payload.region, "language": payload.language
    }
    r = await db.execute(csql, params)
    cid = r.scalar()

    if payload.tags:
        # --- SEÇENEK A: EKSİK TAG'LERİ OLUŞTUR (MVP için pratik)
        # DİKKAT: RLS policy "admin-only insert" ise permission hatası alırsın (aşağıda seçenekler var)
        await db.execute(text("""
            insert into public.tags (slug, label)
            select t, initcap(replace(t, '-', ' '))
            from unnest(cast(:tags as text[])) as u(t)
            on conflict (slug) do nothing
        """), {"tags": payload.tags})

        # Content <-> Tags eşle
        await db.execute(text("""
            insert into public.content_tags (content_id, tag_id)
            select :cid, tg.id
            from public.tags tg
            where tg.slug = any(cast(:tags as text[]))
        """), {"cid": cid, "tags": payload.tags})

        # --- Eğer SEÇENEK B'yi (tag eklememeyi) tercih edersen yukarıdaki insert into public.tags bloğunu kaldır.

    await db.commit()
    return {"id": str(cid)}

@router.get("", response_model=list[dict])
async def list_content(
    q: Optional[str] = None,
    tag: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    base = """
        select
          c.id, c.author_id, c.type, c.title, c.summary, c.visibility,
          c.region, c.language, c.created_at
        from public.content c
        left join public.content_tags ct on ct.content_id = c.id
        left join public.tags tg on tg.id = ct.tag_id
        where c.is_published = true
          and c.visibility = 'public'
    """
    args: dict = {}
    if q:
        base += " and (c.title ilike :q or c.summary ilike :q or c.body ilike :q)"
        args["q"] = f"%{q}%"
    if tag:
        base += " and tg.slug = :tag"
        args["tag"] = tag

    # avoid duplicates from joins; either GROUP BY PK (Postgres ok) or DISTINCT ON
    base += " group by c.id order by c.created_at desc limit 50"

    res = await db.execute(text(base), args)
    return [row_to_dict(row) for row in res.fetchall()]

@router.get("/{content_id}", response_model=dict)
async def get_content(content_id: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(text("""
        select
          c.id, c.author_id, c.type, c.title, c.summary, c.body,
          c.evidence, c.visibility, c.region, c.language,
          c.created_at, c.updated_at
        from public.content c
        where c.id = :id and c.is_published = true
    """), {"id": content_id})
    row = res.first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    return row_to_dict(row)
