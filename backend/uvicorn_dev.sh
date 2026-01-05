#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
exec uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
