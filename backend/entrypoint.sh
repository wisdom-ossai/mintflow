#!/bin/sh
set -e

echo "Running Alembic migrations..."
alembic upgrade head
echo "Migrations complete."

# Railway healthchecks and private networking use $PORT (typically 8080).
# The public domain's target port is stuck on 8000 (see Network Flow
# destinations :8000) which produces Hikari 502s in ~1ms.
PORT="${PORT:-8080}"

if [ "$PORT" != "8000" ]; then
  echo "Forwarding 0.0.0.0:8000 → 127.0.0.1:${PORT} (public domain target port)"
  socat TCP-LISTEN:8000,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:"${PORT}" &
fi

# Single worker — in-process APScheduler must not duplicate across workers.
exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "$PORT" \
  --workers 1 \
  --loop uvloop \
  --access-log
