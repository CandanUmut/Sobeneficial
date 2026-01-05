# app/api/v1/routes_psm_engagements.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import json
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter(prefix="/psm", tags=["psm"])

@router.get("/engagements/{eid}", response_model=dict)
async def get_engagement(eid: str, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    res = await db.execute(
        text("""
          select e.*, rq.message as request_message,
                 pra.username as practitioner_username, reqp.username as requester_username
          from public.engagements e
          join public.offer_requests rq on rq.id = e.request_id
          left join public.profiles pra on pra.id = e.practitioner_id
          left join public.profiles reqp on reqp.id = e.requester_id
          where e.id=:id
        """),
        {"id": eid},
    )
    row = res.first()
    if not row:
        raise HTTPException(404, "Engagement not found")
    E = row_to_dict(row)
    # (optional) ensure party
    if str(E["practitioner_id"]) != str(user_id) and str(E["requester_id"]) != str(user_id):
        raise HTTPException(403, "not a party")
    return E

@router.patch("/engagements/{eid}", response_model=dict)
async def update_engagement(eid: str, payload: dict, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    """
    schedule: {"action":"schedule","scheduled_at":"2025-01-15T18:00:00Z"}
    complete: {"action":"complete"}
    cancel:   {"action":"cancel","reason":"..."}
    """
    action = (payload.get("action") or "").lower()
    if action not in {"schedule","complete","cancel"}:
        raise HTTPException(422, "invalid action")

    res = await db.execute(text("select * from public.engagements where id=:id"), {"id": eid})
    row = res.first()
    if not row:
        raise HTTPException(404, "not found")
    E = row._mapping

    # role checks
    if action in {"schedule","complete"} and str(E["practitioner_id"]) != str(user_id):
        raise HTTPException(403, "only practitioner can schedule/complete")
    if action == "cancel" and (str(E["practitioner_id"]) != str(user_id) and str(E["requester_id"]) != str(user_id)):
        raise HTTPException(403, "only parties can cancel")

    if action == "schedule":
        sch = payload.get("scheduled_at")
        if not sch:
            raise HTTPException(422, "scheduled_at required")
        await db.execute(
            text("""
              update public.engagements
              set state='scheduled',
                  scheduled_at=:sch,
                  audit = coalesce(audit,'[]'::jsonb) || jsonb_build_object('at', now(), 'actor', :actor, 'action','schedule','scheduled_at',:sch)
              where id=:id
            """),
            {"id": eid, "sch": sch, "actor": user_id},
        )
    elif action == "complete":
        await db.execute(
            text("""
              update public.engagements
              set state='completed', completed_at=now(),
                  audit = coalesce(audit,'[]'::jsonb) || jsonb_build_object('at', now(), 'actor', :actor, 'action','complete')
              where id=:id
            """),
            {"id": eid, "actor": user_id},
        )
    elif action == "cancel":
        reason = payload.get("reason") or ""
        await db.execute(text("""
             with upd as (
               update public.engagements
               set state='cancelled', cancellation_reason=:r,
                   audit = coalesce(audit,'[]'::jsonb) || jsonb_build_object('at', now(), 'actor', :actor, 'action','cancel','reason',:r)
               where id=:id
               returning slot_id
             )
             update public.offer_slots s
             set reserved = greatest(s.reserved - 1, 0),
                 status = case when s.status='full' and s.reserved - 1 < s.capacity then 'open' else s.status end,
                 updated_at = now()
             from upd
             where s.id = upd.slot_id and upd.slot_id is not null
           """),
            {"id": eid, "actor": user_id, "r": reason},
        )

    await db.commit()
    return {"ok": True}
