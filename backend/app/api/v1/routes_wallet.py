from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.get("/me", response_model=dict)
async def my_wallet(db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    acc = await db.execute(text("select user_id, balance, updated_at from public.wallet_accounts where user_id=:u"), {"u": user_id})
    a = acc.first()
    if not a:
        # hesap yoksa oluştur
        await db.execute(text("insert into public.wallet_accounts(user_id, balance) values (:u, 100) on conflict do nothing"), {"u": user_id})
        await db.commit()
        a = (await db.execute(text("select user_id, balance, updated_at from public.wallet_accounts where user_id=:u"), {"u": user_id})).first()
    tx = await db.execute(text("""
        select id, from_user, to_user, amount, reason, created_at
        from public.wallet_txns
        where from_user=:u or to_user=:u
        order by created_at desc
        limit 20
    """), {"u": user_id})
    return {
        "account": row_to_dict(a),
        "txns": [row_to_dict(t) for t in tx.fetchall()]
    }

@router.post("/tip", response_model=dict)
async def tip_user(to_user: str, amount: int, reason: str = "tip",
                   db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    if amount <= 0:
        raise HTTPException(400, "amount must be > 0")
    try:
        await db.execute(text("select public.wallet_transfer(:f,:t,:a,:r)"), {"f": user_id, "t": to_user, "a": amount, "r": reason})
        await db.commit()
    except Exception as e:
        raise HTTPException(400, f"transfer failed: {e}")
    return {"ok": True}
