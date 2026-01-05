# app/api/v1/routes_psm_ai.py
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id

router = APIRouter(prefix="/psm", tags=["psm-ai"])

@router.post("/ai/answer", response_model=dict)
async def ai_answer(payload: dict, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    """
    Body: {"question":"...", "topic_tag":"legal|psychological|career|other"}
    Returns: templated 'AI (beta)' text + 3 verified orgs (offers) as handoff.
    """
    q = (payload.get("question") or "").strip()
    topic = (payload.get("topic_tag") or "other").lower()

    # very simple curated response
    answer = (
        "AI (beta): This is general information, not professional advice. "
        "For sensitive cases, please connect with verified organizations below."
    )
    # pick 3 top-rated offers by type
    res = await db.execute(
        text("""
          select id, title, region, avg_stars, ratings_count
          from public.offer_public
          where type = :t
          order by avg_stars desc, ratings_count desc nulls last
          limit 3
        """),
        {"t": topic},
    )
    orgs = [dict(r._mapping) for r in res.fetchall()]
    return {
        "answer": answer,
        "badge": "AI (beta)",
        "sources": [{"title": "General safety note", "url": "https://example.org/safety"}],
        "handoff_note": "These verified offers may help:",
        "verified_orgs": orgs,
    }
