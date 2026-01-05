from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text, bindparam
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from pydantic import BaseModel, Field

from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

# ---------- Schemas ----------
class QuestionCreate(BaseModel):
    title: str
    body: Optional[str] = None
    tags: list[str] = Field(default_factory=list)
    visibility: Optional[str] = "public"
    # store images/links metadata here, e.g. [{"kind":"image","url":"..."}]
    sources: Optional[list[dict]] = Field(default_factory=list)

class AnswerCreate(BaseModel):
    question_id: str
    body: str
    evidence: Optional[str] = "n_a"
    sources: Optional[list[dict]] = Field(default_factory=list)

# ===================== QUESTIONS =====================

@router.post("/questions", response_model=dict)
async def create_question(
    payload: QuestionCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    stmt = text("""
        insert into public.questions (asker_id, title, body, tags, visibility, sources)
        values (:uid, :title, :body, :tags, :visibility, coalesce(:sources, '[]'::jsonb))
        returning id
    """).bindparams(
        bindparam("sources", type_=JSONB)  # 👈 tell asyncpg this is JSONB
    )

    r = await db.execute(
        stmt,
        {
            "uid": user_id,
            "title": payload.title,
            "body": payload.body,
            "tags": payload.tags,         # text[] is fine with a Python list
            "visibility": payload.visibility,
            "sources": payload.sources or [],  # Python list is OK now
        },
    )
    qid = r.scalar()
    await db.commit()
    return {"id": str(qid)}

@router.get("/questions", response_model=list[dict])
async def list_questions(
    q: Optional[str] = None,
    tag: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    base = """
        select
          q.id, q.asker_id, q.title, q.body, q.tags, q.visibility,
          q.sources,
          q.created_at, q.updated_at,
          coalesce((
            select count(*)::int from public.views v
            where v.entity='question' and v.entity_id=q.id
          ), 0) as views,
          coalesce((
            select avg(rt.stars)::float from public.ratings rt
            where rt.entity='question' and rt.entity_id=q.id
          ), 0.0) as avg_stars,
          coalesce((
            select count(*)::int from public.ratings rt2
            where rt2.entity='question' and rt2.entity_id=q.id
          ), 0) as ratings_count
        from public.questions q
        where q.visibility='public'
    """
    args: dict = {}
    if q:
        base += " and (q.title ilike :q or q.body ilike :q)"
        args["q"] = f"%{q}%"
    if tag:
        base += " and :t = any(q.tags)"
        args["t"] = tag
    base += " order by q.created_at desc limit 100"

    res = await db.execute(text(base), args)
    return [row_to_dict(r) for r in res.fetchall()]

@router.get("/questions/{qid}", response_model=dict)
async def get_question(qid: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        text("""
            select
              q.id, q.asker_id, q.title, q.body, q.tags, q.visibility,
              q.sources,
              q.created_at, q.updated_at,
              coalesce((
                select count(*)::int from public.views v
                where v.entity='question' and v.entity_id=q.id
              ), 0) as views,
              coalesce((
                select avg(rt.stars)::float from public.ratings rt
                where rt.entity='question' and rt.entity_id=q.id
              ), 0.0) as avg_stars,
              coalesce((
                select count(*)::int from public.ratings rt2
                where rt2.entity='question' and rt2.entity_id=q.id
              ), 0) as ratings_count
            from public.questions q
            where q.id=:id
        """),
        {"id": qid},
    )
    row = res.first()
    if not row:
        raise HTTPException(404, "Not found")
    return row_to_dict(row)

@router.delete("/questions/{qid}", status_code=204)
async def delete_question(
    qid: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    owner = await db.execute(
        text("select asker_id from public.questions where id=:id"),
        {"id": qid},
    )
    row = owner.first()
    if not row:
        raise HTTPException(404, "Question not found")
    if str(row._mapping["asker_id"]) != str(user_id):
        raise HTTPException(403, "Only owner can delete the question")

    await db.execute(text("delete from public.questions where id=:id"), {"id": qid})
    await db.commit()
    return

# ===================== ANSWERS =====================

@router.post("/answers", response_model=dict)
async def create_answer(
    payload: AnswerCreate,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    stmt = text("""
        insert into public.answers (question_id, author_id, body, evidence, sources)
        values (:qid, :uid, :body, :evidence, coalesce(:sources, '[]'::jsonb))
        returning id
    """).bindparams(
        bindparam("sources", type_=JSONB)  # 👈 JSONB binding
    )

    r = await db.execute(
        stmt,
        {
            "qid": payload.question_id,
            "uid": user_id,
            "body": payload.body,
            "evidence": payload.evidence,
            "sources": payload.sources or [],
        },
    )
    aid = r.scalar()
    await db.commit()
    return {"id": str(aid)}

@router.get("/questions/{qid}/answers", response_model=list[dict])
async def list_answers(qid: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        text("""
            select id, question_id, author_id, body, evidence, sources,
                   is_accepted, created_at, updated_at
            from public.answers
            where question_id=:qid
            order by created_at asc
        """),
        {"qid": qid},
    )
    return [row_to_dict(r) for r in res.fetchall()]

@router.post("/questions/{qid}/accept/{aid}", status_code=204)
async def accept_answer(
    qid: str,
    aid: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    owner = await db.execute(
        text("select asker_id from public.questions where id=:id"),
        {"id": qid},
    )
    row = owner.first()
    if not row:
        raise HTTPException(404, "Question not found")
    if str(row._mapping["asker_id"]) != str(user_id):
        raise HTTPException(403, "Only question owner can accept an answer")

    await db.execute(
        text("select public.accept_answer(:qid, :aid, :actor)"),
        {"qid": qid, "aid": aid, "actor": user_id},
    )
    await db.commit()
    return
