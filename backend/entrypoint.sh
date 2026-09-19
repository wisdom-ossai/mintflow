#!/bin/sh
set -e

echo "Running Alembic migrations..."
alembic upgrade head
echo "Migrations complete."

# Railway sets PORT (usually 8080). Default must match EXPOSE or the
# edge proxies to the wrong port and /health returns 502.
PORT="${PORT:-8080}"

# Single worker — in-process APScheduler must not duplicate across workers.
exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "$PORT" \
  --workers 1 \
  --loop uvloop \
  --access-log
