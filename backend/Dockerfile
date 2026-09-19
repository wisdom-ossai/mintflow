# ─── Build stage ───────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies into a virtual env
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# ─── Production stage ──────────────────────────────────────────────────────
FROM python:3.12-slim AS production

WORKDIR /app

# System deps only (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Copy venv from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY . .

# Non-root user for security. chmod while still root.
RUN chmod +x /app/entrypoint.sh && \
    adduser --disabled-password --gecos "" mintflow && \
    chown -R mintflow:mintflow /app
USER mintflow

# Railway injects PORT at runtime (typically 8080). EXPOSE must match that
# or the public domain's target port stays on 8000 and Hikari returns 502.
EXPOSE 8080

# Probe the same port uvicorn binds ($PORT). Hardcoding 8000 marks the
# container unhealthy while the app is healthy on 8080.
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import os,httpx; httpx.get('http://127.0.0.1:%s/health' % os.environ.get('PORT','8080')).raise_for_status()"

# Migrate then start. Railway startCommand must also use this script
# (it overrides Dockerfile CMD/ENTRYPOINT).
ENTRYPOINT ["/app/entrypoint.sh"]
