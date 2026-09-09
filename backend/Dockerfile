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

# Expose port
EXPOSE 8000

# Health check (Railway uses healthcheckPath; this is for local docker)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

# Migrate then start. Railway startCommand must also use this script
# (it overrides Dockerfile CMD/ENTRYPOINT).
ENTRYPOINT ["/app/entrypoint.sh"]
