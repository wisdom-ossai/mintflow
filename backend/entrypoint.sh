#!/bin/sh
set -e

echo "Running Alembic migrations..."
alembic upgrade head
echo "Migrations complete."

PORT="${PORT:-8000}"

# Single worker — in-process APScheduler must not duplicate across workers.
exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "$PORT" \
  --workers 1 \
  --loop uvloop \
  --access-log
