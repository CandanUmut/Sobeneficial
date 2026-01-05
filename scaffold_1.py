# generate_scaffold_part1.py
# ---------------------------------------------------------
# Part 1 of 2: Creates a runnable FastAPI MVP backend
# with Supabase JWT auth & Postgres (async SQLAlchemy).
# Smart auto-discovery allows Part 2 to add extra routes
# without changing this scaffold.
# ---------------------------------------------------------
import os, stat
from pathlib import Path
from textwrap import dedent as D

ROOT = Path.cwd() / "backend"

def write(path: Path, content: str, executable: bool=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(D(content).strip() + "\n")
    if executable:
        st = os.stat(path)
        os.chmod(path, st.st_mode | stat.S_IEXEC)

def main():
    # ----------------- root files -----------------
    write(ROOT / ".gitignore", """
        .venv/
        __pycache__/
        .pytest_cache/
        .DS_Store
        .env
        dist/
        build/
    """)
    write(ROOT / "README.md", """
        # MVP Backend (FastAPI + Supabase) — Part 1

        This is the first scaffold: runnable API with core endpoints and
        auto-discovery for future modules (added by Part 2).

        ## Quickstart
        ```bash
        python -m venv .venv
        source .venv/bin/activate   # Windows: .venv\\Scripts\\activate
        pip install -r requirements.txt
        cp .env.example .env
        ./uvicorn_dev.sh
        ```
        Visit http://127.0.0.1:8000/api/docs

        ## Env Vars (see .env.example)
        - DATABASE_URL: Supabase Postgres URI (include `?sslmode=require`)
        - SUPABASE_JWKS_URL: https://<project>.supabase.co/auth/v1/.well-known/jwks.json
        - SUPABASE_AUDIENCE: usually "authenticated"
        - DEV_ALLOW_UNVERIFIED: "true" to allow anon in dev (no Authorization header)
        - LOG_LEVEL: info|debug
        - API_PREFIX: default /api
        - CORS_ORIGINS: comma separated list (e.g. http://localhost:3000)

        ## Endpoints included
        - GET  /api/healthz
        - GET  /api/auth/me
        - GET  /api/profiles/me
        - PUT  /api/profiles/me
        - POST /api/rfh
        - GET  /api/rfh
        - GET  /api/rfh/{id}
        - GET  /api/match/{rfh_id}
    """)
    write(ROOT / ".env.example", """
        # --- Core ---
        DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST:PORT/DBNAME?sslmode=require
        SUPABASE_JWKS_URL=https://YOUR_PROJECT.supabase.co/auth/v1/.well-known/jwks.json
        SUPABASE_AUDIENCE=authenticated
        DEV_ALLOW_UNVERIFIED=true
        LOG_LEVEL=info
        API_PREFIX=/api
        APP_NAME=NovaBridge
        APP_ENV=dev
        APP_HOST=0.0.0.0
        APP_PORT=8000
        REQUEST_TIMEOUT=15

        # CORS
        CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:5173
    """)
    write(ROOT / "requirements.txt", """
        fastapi==0.115.0
        uvicorn[standard]==0.30.6
        pydantic==2.9.2
        pydantic-settings==2.4.0
        SQLAlchemy==2.0.36
        asyncpg==0.29.0
        httpx==0.27.2
        python-jose[cryptography]==3.3.0
        loguru==0.7.2
        orjson==3.10.7
    """)
    write(ROOT / "uvicorn_dev.sh", """
        #!/usr/bin/env bash
        export PYTHONUNBUFFERED=1
        exec uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
    """, executable=True)

    # ----------------- app core -----------------
    write(ROOT / "app/__init__.py", "from .main import app\n")
    write(ROOT / "app/main.py", """
        from fastapi import FastAPI
        from fastapi.middleware.cors import CORSMiddleware
        from fastapi.responses import ORJSONResponse
        from .core.config import settings
        from .utils.logger import setup_logging
        from .api.v1 import router as api_router

        setup_logging()

        app = FastAPI(title=settings.APP_NAME, default_response_class=ORJSONResponse)

        origins = [o.strip() for o in settings.CORS_ORIGINS.split(",") if o.strip()]
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins or ["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
            expose_headers=["*"],
        )

        app.include_router(api_router, prefix=settings.API_PREFIX)
    """)
    write(ROOT / "app/core/config.py", """
        from pydantic_settings import BaseSettings

        class Settings(BaseSettings):
            APP_NAME: str = "NovaBridge"
            APP_ENV: str = "dev"
            API_PREFIX: str = "/api"
            DATABASE_URL: str
            SUPABASE_JWKS_URL: str
            SUPABASE_AUDIENCE: str = "authenticated"
            DEV_ALLOW_UNVERIFIED: bool = True
            LOG_LEVEL: str = "info"
            APP_HOST: str = "0.0.0.0"
            APP_PORT: int = 8000
            REQUEST_TIMEOUT: int = 15
            CORS_ORIGINS: str = "http://localhost:3000"

            class Config:
                env_file = ".env"
                extra = "ignore"

        settings = Settings()
    """)
    write(ROOT / "app/utils/logger.py", """
        from loguru import logger
        import sys

        def setup_logging():
            logger.remove()
            logger.add(sys.stderr, level="INFO", backtrace=False, diagnose=False)
            return logger
    """)
    write(ROOT / "app/db/session.py", """
        from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
        from sqlalchemy import text
        from ..core.config import settings

        engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True)
        async_session = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

        async def ping_db():
            async with engine.begin() as conn:
                await conn.execute(text("select 1"))
    """)
    write(ROOT / "app/middleware/auth.py", """
        from typing import Optional, Dict, Any
        from jose import jwt
        import httpx
        from fastapi import Header, HTTPException
        from ..core.config import settings

        _JWKS: Optional[Dict[str, Any]] = None

        async def _get_jwks() -> Dict[str, Any]:
            global _JWKS
            if _JWKS is not None:
                return _JWKS
            async with httpx.AsyncClient(timeout=settings.REQUEST_TIMEOUT) as client:
                r = await client.get(settings.SUPABASE_JWKS_URL)
                r.raise_for_status()
                _JWKS = r.json()
                return _JWKS

        async def get_current_user_id(authorization: Optional[str] = Header(None)) -> Optional[str]:
            # Dev mode: allow anonymous for public GETs if no Authorization
            if settings.DEV_ALLOW_UNVERIFIED and not authorization:
                return None
            if not authorization:
                raise HTTPException(status_code=401, detail="Missing Authorization")

            scheme, _, token = authorization.partition(" ")
            if scheme.lower() != "bearer" or not token:
                raise HTTPException(status_code=401, detail="Invalid auth scheme")

            jwks = await _get_jwks()
            try:
                unverified = jwt.get_unverified_header(token)
                kid = unverified.get("kid")
                key = next((k for k in jwks["keys"] if k["kid"] == kid), None)
                if not key:
                    raise HTTPException(status_code=401, detail="JWK kid not found")

                claims = jwt.decode(
                    token,
                    key,
                    algorithms=[key.get("alg", "RS256")],
                    audience=settings.SUPABASE_AUDIENCE,
                    options={"verify_at_hash": False},
                )
            except Exception as e:
                raise HTTPException(status_code=401, detail=f"Token error: {str(e)}")

            sub = claims.get("sub")
            if not sub:
                raise HTTPException(status_code=401, detail="Token missing sub")
            return sub  # auth.users.id (UUID)
    """)

    # ----------------- schemas -----------------
    write(ROOT / "app/schemas/__init__.py", "")
    write(ROOT / "app/schemas/common.py", """
        from pydantic import BaseModel
        from typing import Any, List, Optional

        class Msg(BaseModel):
            message: str

        class Paginated(BaseModel):
            items: list[Any]
            total: int
    """)
    write(ROOT / "app/schemas/profiles.py", """
        from pydantic import BaseModel
        from typing import List, Optional

        class Profile(BaseModel):
            id: str
            username: Optional[str] = None
            full_name: Optional[str] = None
            avatar_url: Optional[str] = None
            bio: Optional[str] = None
            languages: List[str] = []
            timezone: Optional[str] = None
            country: Optional[str] = None
            region: Optional[str] = None
            roles: List[str] = []
            reputation: int = 0
            offers: List[str] = []
            needs: List[str] = []
            anon_allowed: bool = True

        class ProfileUpdate(BaseModel):
            username: Optional[str] = None
            full_name: Optional[str] = None
            avatar_url: Optional[str] = None
            bio: Optional[str] = None
            languages: Optional[List[str]] = None
            timezone: Optional[str] = None
            country: Optional[str] = None
            region: Optional[str] = None
            offers: Optional[List[str]] = None
            needs: Optional[List[str]] = None
            anon_allowed: Optional[bool] = None
    """)
    write(ROOT / "app/schemas/rfh.py", """
        from pydantic import BaseModel
        from typing import List, Optional

        class RFHCreate(BaseModel):
            title: str
            body: str | None = None
            tags: List[str] = []
            sensitivity: str = "normal"
            anonymous: bool = False
            region: str | None = None
            language: str = "tr"

        class RFH(BaseModel):
            id: str
            requester_id: str | None = None
            title: str
            body: str | None = None
            tags: List[str] = []
            sensitivity: str
            anonymous: bool
            status: str
            region: str | None = None
            language: str

        class MatchResult(BaseModel):
            helper_id: str
            score: float
            note: str | None = None
    """)

    # ----------------- small util -----------------
    write(ROOT / "app/utils/dbhelpers.py", """
        from typing import Any, Mapping

        def row_to_dict(row: Mapping[str, Any]) -> dict:
            return dict(row._mapping) if hasattr(row, "_mapping") else dict(row)
    """)

    # ----------------- API (v1) -----------------
    write(ROOT / "app/api/__init__.py", "")
    write(ROOT / "app/api/deps.py", """
        from typing import Optional
        from fastapi import Depends, HTTPException
        from sqlalchemy.ext.asyncio import AsyncSession
        from ..db.session import async_session
        from ..middleware.auth import get_current_user_id

        async def get_db() -> AsyncSession:
            async with async_session() as session:
                yield session

        async def require_user_id(user_id: Optional[str] = Depends(get_current_user_id)) -> str:
            if not user_id:
                raise HTTPException(status_code=401, detail="Unauthorized")
            return user_id
    """)
    write(ROOT / "app/api/v1/__init__.py", """
        from fastapi import APIRouter
        from .routes_health import router as health
        from .routes_auth import router as auth
        from .routes_profiles import router as profiles
        from .routes_rfh import router as rfh
        from .routes_match import router as match

        # Auto-discovery for optional modules (added by Part 2)
        OPTIONAL_MODULES = [
            ("content", ".routes_content"),
            ("qa", ".routes_qa"),
            ("projects", ".routes_projects"),
            ("events", ".routes_events"),
            ("notifications", ".routes_notifications"),
            ("reports", ".routes_reports"),
        ]

        router = APIRouter()
        router.include_router(health)
        router.include_router(auth, prefix="/auth", tags=["auth"])
        router.include_router(profiles, prefix="/profiles", tags=["profiles"])
        router.include_router(rfh, prefix="/rfh", tags=["rfh"])
        router.include_router(match, prefix="/match", tags=["match"])

        # Try include optional routers if files exist (no edits needed in Part 2)
        for tag, modname in OPTIONAL_MODULES:
            try:
                module = __import__(__name__.rsplit(".", 1)[0] + modname, fromlist=["router"])
                router.include_router(module.router, prefix=f"/{tag}", tags=[tag])
            except Exception:
                # silently skip if not present yet
                pass
    """)
    write(ROOT / "app/api/v1/routes_health.py", """
        from fastapi import APIRouter
        from ...db.session import ping_db

        router = APIRouter(tags=["health"])

        @router.get("/healthz")
        async def healthz():
            try:
                await ping_db()
                return {"status": "ok"}
            except Exception as e:
                return {"status": "db_error", "detail": str(e)}
    """)
    write(ROOT / "app/api/v1/routes_auth.py", """
        from fastapi import APIRouter, Depends
        from ...middleware.auth import get_current_user_id

        router = APIRouter()

        @router.get("/me")
        async def me(user_id: str | None = Depends(get_current_user_id)):
            # In dev without token this returns {"user_id": null}
            return {"user_id": user_id}
    """)
    write(ROOT / "app/api/v1/routes_profiles.py", """
        from fastapi import APIRouter, Depends, HTTPException
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from ...api.deps import get_db, require_user_id
        from ...schemas.profiles import Profile, ProfileUpdate
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.get("/me", response_model=Profile | dict)
        async def get_me(db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            q = await db.execute(text("select * from public.profiles where id=:uid"), {"uid": user_id})
            row = q.first()
            if not row:
                raise HTTPException(404, "Profile not found")
            return row_to_dict(row)

        @router.put("/me", response_model=dict)
        async def update_me(payload: ProfileUpdate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            fields = {k: v for k, v in payload.model_dump(exclude_none=True).items()}
            if not fields:
                return {"updated": False}
            sets = ", ".join([f"{k}=:{k}" for k in fields.keys()])
            fields["uid"] = user_id
            sql = text(f"update public.profiles set {sets}, updated_at=now() where id=:uid")
            await db.execute(sql, fields)
            await db.commit()
            return {"updated": True}
    """)
    write(ROOT / "app/api/v1/routes_rfh.py", """
        from fastapi import APIRouter, Depends, HTTPException
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from typing import Optional
        from ...api.deps import get_db, require_user_id
        from ...schemas.rfh import RFHCreate
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.post("", response_model=dict)
        async def create_rfh(payload: RFHCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            sql = text(\"\"\"
                insert into public.rfh (requester_id, title, body, tags, sensitivity, anonymous, region, language)
                values (:uid, :title, :body, :tags, :sensitivity, :anonymous, :region, :language)
                returning id
            \"\"\")
            params = {
                "uid": user_id,
                "title": payload.title,
                "body": payload.body,
                "tags": payload.tags,
                "sensitivity": payload.sensitivity,
                "anonymous": payload.anonymous,
                "region": payload.region,
                "language": payload.language,
            }
            r = await db.execute(sql, params)
            new_id = r.scalar()
            await db.commit()
            return {"id": str(new_id)}

        @router.get("", response_model=list[dict])
        async def list_rfh(q: Optional[str] = None, tag: Optional[str] = None, db: AsyncSession = Depends(get_db)):
            base = "select id, requester_id, title, body, tags, sensitivity, anonymous, status, region, language, created_at, updated_at from public.rfh_public"
            conds = []
            args = {}
            if q:
                conds.append("(title ilike :q or body ilike :q)")
                args["q"] = f"%{q}%"
            if tag:
                conds.append(":t = any(tags)")
                args["t"] = tag
            if conds:
                base += " where " + " and ".join(conds)
            base += " order by created_at desc limit 50"
            res = await db.execute(text(base), args)
            return [row_to_dict(r) for r in res.fetchall()]

        @router.get("/{rfh_id}", response_model=dict)
        async def get_rfh(rfh_id: str, db: AsyncSession = Depends(get_db)):
            res = await db.execute(text("select * from public.rfh_public where id=:id"), {"id": rfh_id})
            row = res.first()
            if not row: raise HTTPException(404, "Not found")
            return row_to_dict(row)
    """)
    write(ROOT / "app/api/v1/routes_match.py", '''
    from fastapi import APIRouter, Depends, HTTPException
    from sqlalchemy import text
    from sqlalchemy.ext.asyncio import AsyncSession
    from ..deps import get_db                     # fixed relative import (from v1 -> api)
    from ...utils.dbhelpers import row_to_dict    # stays the same (api.v1 -> app.utils)

    router = APIRouter(prefix="/match", tags=["match"])

    @router.get("/{rfh_id}", response_model=list[dict])
    async def match_helpers(rfh_id: str, db: AsyncSession = Depends(get_db)):
        # v0: simple tag overlap + reputation boost
        rfh = await db.execute(
            text("select tags, language, region from public.rfh where id = :id"),
            {"id": rfh_id},
        )
        r = rfh.first()
        if not r:
            raise HTTPException(status_code=404, detail="RFH not found")

        tags = (r._mapping["tags"] or [])
        if not tags:
            res = await db.execute(
                text(
                    "select id as helper_id, reputation::float as score "
                    "from public.profiles "
                    "order by reputation desc limit 10"
                )
            )
            return [row_to_dict(x) for x in res.fetchall()]

        # NOTE: asyncpg handles Python list -> Postgres text[] for :tags.
        res = await db.execute(
            text(
                """
                select id as helper_id,
                       (
                         select count(*)
                         from unnest(offers) t(tag)
                         where t.tag = any(:tags)
                       )::float
                       + reputation / 100.0 as score
                from public.profiles
                where array_length(offers, 1) is not null
                order by score desc
                limit 10
                """
            ),
            {"tags": tags},
        )
        return [row_to_dict(x) for x in res.fetchall()]
    ''')

    print(f"✅ Scaffold Part 1 created at: {ROOT}")

if __name__ == "__main__":
    main()