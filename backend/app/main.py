from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse

from .core.config import settings
from .utils.logger import setup_logging
from .api.v1 import router as api_router

setup_logging()

app = FastAPI(
    title=getattr(settings, "APP_NAME", "BenefiSocial API"),
    default_response_class=ORJSONResponse,
)

# CORS
origins = [o.strip() for o in getattr(settings, "CORS_ORIGINS", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# API
api_prefix = getattr(settings, "API_PREFIX", "/api")
if not api_prefix.startswith("/"):
    api_prefix = f"/{api_prefix}"
app.include_router(api_router, prefix=api_prefix)
