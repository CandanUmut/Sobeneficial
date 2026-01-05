from __future__ import annotations
import time
from typing import Optional
from fastapi import Header
from jose import jwt
import httpx

from ..core.config import settings

# Basit JWKS cache (10 dk)
_JWKS_CACHE: dict | None = None
_JWKS_FETCH_TS: float = 0.0
_JWKS_TTL = 600.0  # seconds

async def _get_jwks() -> dict | None:
    global _JWKS_CACHE, _JWKS_FETCH_TS
    if not settings.SUPABASE_JWKS_URL:
        return None
    now = time.time()
    if _JWKS_CACHE and (now - _JWKS_FETCH_TS) < _JWKS_TTL:
        return _JWKS_CACHE
    async with httpx.AsyncClient(timeout=10.0) as c:
        r = await c.get(settings.SUPABASE_JWKS_URL)
        r.raise_for_status()
        _JWKS_CACHE = r.json()
        _JWKS_FETCH_TS = now
        return _JWKS_CACHE

async def _decode_supabase_jwt(token: str) -> Optional[dict]:
    """
    PROD: JWKS ile doğrula (RS256).
    DEV: JWKS yoksa veya DEV_ALLOW_UNVERIFIED=True ise unverified claims’tan oku.
    """
    # PROD yolu: JWKS doğrulaması
    if settings.SUPABASE_JWKS_URL and not settings.DEV_ALLOW_UNVERIFIED:
        jwks = await _get_jwks()
        if not jwks or "keys" not in jwks:
            return None
        hdr = jwt.get_unverified_header(token)
        kid = hdr.get("kid")
        key = next((k for k in jwks["keys"] if k.get("kid") == kid), None)
        if not key:
            return None
        # Supabase RS256
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            options={
                "verify_aud": False,  # Supabase projelerinde aud genelde 'authenticated'; esnek bırakalım
            },
        )
        return claims

    # DEV yolu: JWKS yok veya DEV_ALLOW_UNVERIFIED=True → imzasız claims
    try:
        claims = jwt.get_unverified_claims(token)
        return claims
    except Exception:
        return None

async def get_current_user_id(
    authorization: Optional[str] = Header(None),
    x_dev_user_id: Optional[str] = Header(None),
) -> Optional[str]:
    """
    Kullanıcı kimliğini döndürür (uuid string) veya None.
    - Authorization: Bearer <jwt> varsa Supabase JWT’den 'sub' alınır.
    - DEV_ALLOW_UNVERIFIED=True ve Authorization yoksa 'x-dev-user-id' kabul edilir.
    """
    # DEV bypass (token yoksa ve dev header geldiyse)
    if settings.DEV_ALLOW_UNVERIFIED and (not authorization) and x_dev_user_id:
        return x_dev_user_id

    if not authorization or not authorization.startswith("Bearer "):
        return None

    token = authorization.split(" ", 1)[1].strip()
    claims = await _decode_supabase_jwt(token)
    if not claims:
        return None

    uid = claims.get("sub")
    return uid
