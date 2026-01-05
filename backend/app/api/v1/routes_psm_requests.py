# app/api/v1/routes_psm_requests.py
from __future__ import annotations

import json
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter(prefix="/psm", tags=["psm"])


@router.post("/requests", response_model=dict)
async def create_request(payload: dict, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    """
    Body:
      {
        "offer_id": uuid,
        "message": str,
        "preferred_times": [{start,end,tz?}, ...],   # optional
        "use_gift": true|false                       # optional; if true, consume a sponsored unit
      }
    """
    offer_id = payload.get("offer_id")
    message = payload.get("message")
    preferred_times = payload.get("preferred_times") or []
    use_gift = bool(payload.get("use_gift"))

    if not offer_id or not message:
        raise HTTPException(422, "offer_id and message required")

    # If the user wants to use a sponsored seat, try to take one *now*.
    gift_id = None

    if use_gift:
        q = await db.execute(text("""
          with pick as (
            select id
              from public.offer_gifts
             where offer_id = cast(:oid as uuid)
               and status = 'active'
               and (valid_until is null or valid_until >= now())
               and used < units
             order by created_at asc
             for update skip locked
             limit 1
          )
          update public.offer_gifts g
             set used = used + 1,
                 updated_at = now()
            from pick
           where g.id = pick.id
          returning g.id
        """), {"oid": str(payload["offer_id"])})
        gift_id = q.scalar()
        if gift_id is None:
            raise HTTPException(status_code=409, detail="No sponsored seats available")

    r = await db.execute(
        text("""
          insert into public.offer_requests
            (offer_id, requester_id, message, preferred_times)
          values
            (:offer, :uid, :msg, CAST(:ptimes AS jsonb))
          returning id
        """),
        {"offer": offer_id, "uid": user_id, "msg": message, "ptimes": json.dumps(preferred_times)},
    )
    rid = r.scalar()
    await db.commit()
    return {"id": str(rid)}


@router.get("/requests/mine", response_model=list[dict])
async def my_requests(
    box: str = Query("sent", pattern="^(sent|received)$"),
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    sent: requests created by me
    received: requests sent to my offers
    """
    if box == "sent":
        res = await db.execute(
            text("""
              select r.*, o.title as offer_title, o.owner_id,
                     p.username as owner_username
                from public.offer_requests r
                join public.offers o on o.id = r.offer_id
           left join public.profiles p on p.id = o.owner_id
               where r.requester_id = :uid
            order by r.created_at desc
            """),
            {"uid": user_id},
        )
    else:
        res = await db.execute(
            text("""
              select r.*, o.title as offer_title, o.owner_id,
                     pr.username as requester_username
                from public.offer_requests r
                join public.offers o on o.id = r.offer_id
           left join public.profiles pr on pr.id = r.requester_id
               where o.owner_id = :uid
            order by r.created_at desc
            """),
            {"uid": user_id},
        )
    return [row_to_dict(r) for r in res.fetchall()]


@router.patch("/requests/{request_id}", response_model=dict)
async def update_request(
    request_id: str,
    payload: dict,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(require_user_id),
):
    """
    Accept : {"action":"accept",  "slot_id"?: uuid, "use_gift"?: true}
    Decline: {"action":"decline", "reason"?: "..."}
    Withdraw (by requester): {"action":"withdraw"}
    """
    action = (payload.get("action") or "").lower()
    if action not in {"accept", "decline", "withdraw"}:
        raise HTTPException(422, "invalid action")

    # Load request + offer + participants
    rq = await db.execute(
        text("""
          select r.*, o.owner_id as offer_owner
            from public.offer_requests r
            join public.offers o on o.id = r.offer_id
           where r.id = :id
        """),
        {"id": request_id},
    )
    row = rq.first()
    if not row:
        raise HTTPException(404, "request not found")
    R = row._mapping  # keys: id, offer_id, requester_id, status, offer_owner, ...

    if action in {"accept", "decline"} and str(R["offer_owner"]) != str(user_id):
        raise HTTPException(403, "only offer owner can accept/decline")
    if action == "withdraw" and str(R["requester_id"]) != str(user_id):
        raise HTTPException(403, "only requester can withdraw")

    # ---- ACCEPT -------------------------------------------------------------
    if action == "accept":
        slot_id: Optional[str] = payload.get("slot_id")
        use_gift: bool = bool(payload.get("use_gift"))
        scheduled_at = None
        gift_id = None

        # If a slot is chosen on accept, reserve atomically (no double booking)
        if slot_id:
            took = await db.execute(
                text("""
                  update public.offer_slots s
                     set reserved = reserved + 1,
                         status   = case
                                      when reserved + 1 >= capacity then 'full'
                                      else status
                                    end,
                         updated_at = now()
                   where s.id = :sid
                     and s.offer_id = :oid
                     and s.status <> 'cancelled'
                     and s.reserved < s.capacity
               returning s.start_at
                """),
                {"sid": slot_id, "oid": R["offer_id"]},
            )
            trow = took.first()
            if not trow:
                raise HTTPException(409, "slot not available")
            scheduled_at = trow._mapping["start_at"]

        # Optionally consume a donated unit (FIFO, skip locked)
        if use_gift:
            dec = await db.execute(
                text("""
                  with picked as (
                      select id
                        from public.offer_gifts
                       where offer_id = :oid
                         and status = 'active'
                         and units_remaining > 0
                         and (valid_until is null or valid_until > now())
                       order by created_at asc
                       for update skip locked
                       limit 1
                  )
                  update public.offer_gifts g
                     set units_remaining = g.units_remaining - 1,
                         status = case
                                   when g.units_remaining - 1 <= 0 then 'exhausted'
                                   else 'active'
                                  end,
                         updated_at = now()
                    from picked
                   where g.id = picked.id
               returning g.id
                """),
                {"oid": R["offer_id"]},
            )
            grow = dec.first()
            if grow:
                gift_id = grow._mapping["id"]

        # mark request accepted
        await db.execute(
            text("update public.offer_requests set status='accepted', updated_at=now() where id=:id"),
            {"id": request_id},
        )

        # create engagement with optional slot & scheduled time; record audit
        # compute state in python to avoid ambiguous parameter typing on :sch
        # --- after you optionally reserve the slot and set `scheduled_at` ---

        state = "scheduled" if scheduled_at is not None else "accepted"

        # Create engagement with explicit casts for every ambiguous param
        e = await db.execute(
            text("""
              insert into public.engagements
                (request_id, practitioner_id, requester_id, state, scheduled_at, slot_id, audit)
              values
                (
                  CAST(:rid   AS uuid),
                  CAST(:prac  AS uuid),
                  CAST(:req   AS uuid),
                  CAST(:state AS text),
                  CAST(:sch   AS timestamptz),
                  CAST(:slot  AS uuid),
                  jsonb_build_array(
                    jsonb_build_object(
                      'at', now(),
                      'actor',   CAST(:actor AS uuid),
                      'action',  'accept',
                      'slot_id', CAST(:slot AS uuid)
                    )
                  )
                )
              returning id
            """),
            {
                "rid": str(request_id),
                "prac": str(R["offer_owner"]),
                "req": str(R["requester_id"]),
                "state": state,
                "sch": scheduled_at,  # None or tz-aware datetime from DB
                "slot": slot_id,  # None or UUID/str
                "actor": str(user_id),  # <— THIS was ambiguous; cast to uuid above
            },
        )

        eid = e.scalar()
        await db.commit()
        return {"ok": True, "engagement_id": str(eid), "scheduled_at": scheduled_at}


    # ---- DECLINE ------------------------------------------------------------
    if action == "decline":
        reason = payload.get("reason") or ""
        await db.execute(
            text("""
              update public.offer_requests
                 set status='declined',
                     decline_reason=:r,
                     updated_at=now()
               where id=:id
            """),
            {"id": request_id, "r": reason},
        )
        await db.commit()
        return {"ok": True}

    # ---- WITHDRAW -----------------------------------------------------------
    if action == "withdraw":
        await db.execute(
            text("update public.offer_requests set status='withdrawn', updated_at=now() where id=:id"),
            {"id": request_id},
        )
        await db.commit()
        return {"ok": True}

    # Should not reach here
    raise HTTPException(400, "unhandled")
