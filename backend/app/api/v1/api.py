# app/api/v1/api.py

from fastapi import APIRouter

from .routes_health import router as health
from .routes_rfh import router as rfh
from .routes_projects import router as projects
from .routes_events import router as events
from .routes_content import router as content
from .routes_qa import router as qa
from .routes_profiles import router as profiles
from .routes_notifications import router as notifications
from .routes_match import router as match

api_router = APIRouter()

# health
api_router.include_router(health)  # /healthz  (örn: /api/healthz) :contentReference[oaicite:1]{index=1}

# list endpoints:
api_router.include_router(rfh,         prefix="/rfh")         # /api/rfh           :contentReference[oaicite:2]{index=2}
api_router.include_router(projects,    prefix="/projects")    # /api/projects      :contentReference[oaicite:3]{index=3}
api_router.include_router(events,      prefix="/events")      # /api/events        :contentReference[oaicite:4]{index=4}
api_router.include_router(qa,          prefix="/qa")          # /api/qa/questions  :contentReference[oaicite:5]{index=5}
api_router.include_router(profiles,    prefix="/profiles")    # /api/profiles/me   :contentReference[oaicite:6]{index=6}
api_router.include_router(notifications, prefix="/notifications")  # /api/notifications :contentReference[oaicite:7]{index=7}

# content router'ın içinde zaten prefix "/content" verilmişse:
#   - ya burada prefix vermeden include et
#   - ya routes_content içindeki prefix'i kaldır.
# Biz şu an içte prefix var kabul edip şöyle ekliyoruz:
api_router.include_router(content)     # /api/content/...     :contentReference[oaicite:8]{index=8}

# match (routes içinde prefix="/match" var):
api_router.include_router(match)       # /api/match/{rfh_id}  :contentReference[oaicite:9]{index=9}
