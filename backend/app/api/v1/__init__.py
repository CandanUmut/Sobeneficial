from fastapi import APIRouter
from importlib import import_module
import logging

from .routes_health import router as health
from .routes_auth import router as auth
from .routes_profiles import router as profiles
from .routes_rfh import router as rfh
from .routes_match import router as match
from .routes_ratings import router as ratings
from .routes_views import router as views
from .routes_entries import router as entries
from .routes_psm_offers import router as psm_offers
from .routes_psm_requests import router as psm_requests
from .routes_psm_engagements import router as psm_engagements
from .routes_psm_ai import router as psm_ai
from .routes_psm_slots import router as psm_slots
# backend/app/api/v1/api.py (or wherever you include routers)
from .routes_psm_gifts import router as gifts_router
from .routes_psm_reviews import router as reviews_router



log = logging.getLogger(__name__)


OPTIONAL_MODULES: list[tuple[str, str]] = [
    ("content", ".routes_content"),
    ("qa", ".routes_qa"),
    ("projects", ".routes_projects"),
    ("events", ".routes_events"),
    ("notifications", ".routes_notifications"),
    ("reports", ".routes_reports"),
]

router = APIRouter()


router.include_router(health)                                  # /api/health
router.include_router(auth,      prefix="/auth",      tags=["auth"])
router.include_router(profiles,  prefix="/profiles",  tags=["profiles"])
router.include_router(rfh,       prefix="/rfh",       tags=["rfh"])
router.include_router(match,     prefix="/match",     tags=["match"])
router.include_router(ratings, prefix="/ratings", tags=["ratings"])
router.include_router(views, prefix="/views", tags=["views"])  # ✅ change
router.include_router(entries, prefix="/entries", tags=["entries"])
# New PSM routes
router.include_router(psm_offers)      # /api/psm/offers...
router.include_router(psm_requests)    # /api/psm/requests...
router.include_router(psm_engagements) # /api/psm/engagements...
router.include_router(psm_ai)          # /api/psm/ai/answer
router.include_router(psm_slots)
router.include_router(gifts_router, tags=["psm-gifts"])
router.include_router(reviews_router)


# app/api/v1/__init__.py
try:
    from .routes_comments import router as comments
    router.include_router(comments, prefix="/comments", tags=["comments"])
except Exception:
    pass


try:
    from .routes_wallet import router as wallet
    router.include_router(wallet, prefix="/wallet", tags=["wallet"])
except Exception:
    pass
_base_pkg = __package__ or __name__  # "app.api.v1"

for tag, modname in OPTIONAL_MODULES:
    try:
        module = import_module(f"{_base_pkg}{modname}")  # ✅
        rtr = getattr(module, "router", None)
        if rtr is None:
            log.warning("Module %s has no 'router'", modname)
            continue


        router_prefix = getattr(rtr, "prefix", "") or ""
        if router_prefix:
            router.include_router(rtr, tags=[tag])
            log.info("Included %s with its own prefix '%s'", tag, router_prefix)
        else:
            router.include_router(rtr, prefix=f"/{tag}", tags=[tag])
            log.info("Included %s under '/%s'", tag, tag)

    except Exception as e:
        log.info("Optional module %s skipped: %s", modname, e)
