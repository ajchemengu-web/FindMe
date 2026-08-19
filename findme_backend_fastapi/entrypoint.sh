#!/usr/bin/env sh
# Runs on every container start (Render, Fly.io, or plain `docker run`). Applies any
# pending Alembic migrations before the API starts serving -- neither platform runs
# migrations for you, and running them here (rather than as a separate manual step)
# means a fresh deploy is never serving against a stale schema.
set -e

alembic upgrade head

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
