# app/db/session.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text
from ..core.config import settings

import ssl
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

try:
    import certifi
except Exception:
    certifi = None


def _force_asyncpg(url: str) -> str:
    if not url:
        raise RuntimeError("DATABASE_URL is empty")
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://"):]
    return url


def _scrub_ssl_query_params(url: str) -> str:
    """
    URL içindeki ssl/sslmode/requiressl/sslrootcert parametrelerini tamamen sök.
    SSL'i sadece connect_args ile kontrol edeceğiz.
    """
    parts = urlsplit(url)
    q = [(k, v) for (k, v) in parse_qsl(parts.query, keep_blank_values=True)
         if k.lower() not in {"ssl", "sslmode", "sslrootcert", "requiressl"}]
    new_query = urlencode(q, doseq=True)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, new_query, parts.fragment))


def _make_ssl_context(mode: str) -> ssl.SSLContext:
    """
    mode:
      - 'strict' -> certifi CA (normal internet için ideal)
      - 'os'     -> OS trust store (Windows/kurumsal CA’ları tanır)
      - 'relax'  -> DEV ONLY: doğrulamayı kapatır
    """
    mode = (mode or "strict").lower()
    if mode == "relax":
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        return ctx
    elif mode == "os":
        return ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)
    else:  # strict
        if certifi:
            return ssl.create_default_context(cafile=certifi.where())
        return ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)


# -- Final URL (asyncpg + ssl params yok)
DATABASE_URL = _scrub_ssl_query_params(_force_asyncpg(settings.DATABASE_URL))
ssl_ctx = _make_ssl_context(settings.DB_SSL_MODE)

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
    connect_args={"ssl": ssl_ctx},  # SSL sadece buradan
)

async_session: async_sessionmaker[AsyncSession] = async_sessionmaker(
    engine, expire_on_commit=False, class_=AsyncSession
)

async def ping_db() -> bool:
    async with engine.connect() as conn:
        await conn.execute(text("select 1"))
    return True
