# MVP Backend (FastAPI + Supabase) — Part 1

This is the first scaffold: runnable API with core endpoints and
auto-discovery for future modules (added by Part 2).

## Quickstart
```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
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
