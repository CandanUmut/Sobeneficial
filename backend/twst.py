
import os, asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text


import os, asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.db.session import DATABASE_URL, _make_ssl_context

print("Final URL (no ssl params):", DATABASE_URL)
print("DB_SSL_MODE:", os.environ.get("DB_SSL_MODE"))

ctx = _make_ssl_context(os.environ.get("DB_SSL_MODE","relax"))

async def main():
    eng = create_async_engine(DATABASE_URL, pool_pre_ping=True, connect_args={"ssl": ctx})
    async with eng.connect() as c:
        r = await c.execute(text("select 'DB OK' msg, now() ts"))
        print(r.first())
    await eng.dispose()

asyncio.run(main())