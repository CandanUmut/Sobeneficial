#!/usr/bin/env bash
set -e
. .venv/bin/activate || source .venv/bin/activate
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
