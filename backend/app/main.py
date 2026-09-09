"""
Mintflow API — main application entry point with full Swagger/OpenAPI documentation.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.exceptions import RequestValidationError

from app.core.config import get_settings
from app.core.openapi import build_openapi_schema, TAGS_METADATA
from app.api.v1.endpoints.transactions import router as transactions_router
from app.api.v1.endpoints.accounts import router as accounts_router
from app.api.v1.endpoints.subscriptions import router as subscriptions_router
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.misc import (
    users_router, dashboard_router, insights_router,
    budgets_router, notifications_router,
)
from app.services.scheduler import scheduler, setup_scheduler

settings = get_settings()
logging.basicConfig(
    level=logging.DEBUG if settings.is_development else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Init before FastAPI() so Starlette/FastAPI integrations can attach.
# Missing, blank, or placeholder DSN → skip. A bad DSN must never crash boot.
if settings.sentry_dsn:
    try:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.APP_ENV,
            traces_sample_rate=0.1,
            send_default_pii=False,
        )
        logger.info("Sentry enabled")
    except Exception:
        logger.warning(
            "SENTRY_DSN is invalid or Sentry failed to start; continuing without it",
            exc_info=True,
        )
else:
    logger.info("Sentry disabled (SENTRY_DSN not set or not a valid DSN)")


# ─── Lifespan ──────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting Mintflow API v{settings.APP_VERSION} [{settings.APP_ENV}]")

    if settings.SCHEDULER_ENABLED:
        setup_scheduler()
        scheduler.start()
        logger.info("Background scheduler started (SCHEDULER_ENABLED=true)")
    else:
        logger.info("Background scheduler disabled (SCHEDULER_ENABLED=false)")

    yield

    if settings.SCHEDULER_ENABLED and scheduler.running:
        scheduler.shutdown(wait=False)
    logger.info("Mintflow API shutting down")


# ─── App ───────────────────────────────────────────────────────────────────
# Disable FastAPI's built-in docs — we serve custom ones below with branding.

app = FastAPI(
    title="Mintflow API",
    version="1.0.0",
    docs_url=None,    # custom endpoint below
    redoc_url=None,   # custom endpoint below
    openapi_url=None if settings.is_production else "/openapi.json",
    openapi_tags=TAGS_METADATA,
    lifespan=lifespan,
)

# Wire custom OpenAPI schema builder
app.openapi = lambda: build_openapi_schema(app)


# ─── CORS ──────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Exception handlers ────────────────────────────────────────────────────

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": "Validation error", "errors": exc.errors()},
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    if settings.is_development:
        raise exc
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An unexpected error occurred."},
    )


# ─── Custom Swagger UI ─────────────────────────────────────────────────────

@app.get("/docs", include_in_schema=False)
async def swagger_ui():
    """
    Branded Swagger UI with Mintflow colours and custom configuration.
    Accessible in development and staging — disabled in production.
    """
    if settings.is_production:
        return JSONResponse(status_code=404, content={"detail": "Not found"})

    html = get_swagger_ui_html(
        openapi_url="/openapi.json",
        title="Mintflow API — Documentation",
        swagger_favicon_url="https://mintflow.app/favicon.ico",
        swagger_ui_parameters={
            "defaultModelsExpandDepth": 1,       # show schemas collapsed
            "defaultTagsExpandDepth": 1,          # show tag groups expanded
            "displayRequestDuration": True,       # show request timing
            "filter": True,                       # enable search box
            "persistAuthorization": True,         # keep JWT across refreshes
            "tryItOutEnabled": True,              # try it out enabled by default
            "syntaxHighlight.theme": "monokai",  # dark code highlighting
        },
    )

    # Inject Mintflow brand styles over Swagger defaults
    branded = html.body.decode().replace(
        "</head>",
        """
<style>
  /* ── Mintflow brand overrides ─────────────────────────────── */
  :root {
    --mintflow-green: #2EAD6A;
    --mintflow-dark:  #0A2E1C;
    --mintflow-gold:  #EDB93A;
    --mintflow-cream: #FAFAF7;
  }

  /* Top bar */
  .swagger-ui .topbar {
    background: var(--mintflow-dark) !important;
    padding: 10px 20px;
  }

  /* Logo replacement */
  .swagger-ui .topbar-wrapper .link::before {
    content: "🌱 mintflow api";
    font-family: Georgia, serif;
    font-size: 20px;
    font-style: italic;
    color: var(--mintflow-cream);
    letter-spacing: -0.02em;
  }

  .swagger-ui .topbar-wrapper .link img { display: none; }

  /* Primary buttons */
  .swagger-ui .btn.execute,
  .swagger-ui .btn.authorize {
    background: var(--mintflow-green) !important;
    border-color: var(--mintflow-green) !important;
    color: #fff !important;
    border-radius: 8px !important;
    font-weight: 500 !important;
  }

  .swagger-ui .btn.authorize svg { fill: #fff !important; }

  /* HTTP method badges */
  .swagger-ui .opblock.opblock-post .opblock-summary-method  { background: var(--mintflow-green) !important; }
  .swagger-ui .opblock.opblock-get  .opblock-summary-method  { background: #185FA5 !important; }
  .swagger-ui .opblock.opblock-patch .opblock-summary-method { background: #854F0B !important; }
  .swagger-ui .opblock.opblock-delete .opblock-summary-method{ background: #A32D2D !important; }

  /* Operation expand border */
  .swagger-ui .opblock.opblock-get    { border-color: #185FA5 !important; }
  .swagger-ui .opblock.opblock-post   { border-color: var(--mintflow-green) !important; }
  .swagger-ui .opblock.opblock-patch  { border-color: #854F0B !important; }
  .swagger-ui .opblock.opblock-delete { border-color: #A32D2D !important; }

  /* Tag group headers */
  .swagger-ui .opblock-tag {
    font-family: Georgia, serif !important;
    font-size: 18px !important;
    font-weight: 400 !important;
    border-bottom: 1px solid #e0e0d8 !important;
  }

  /* Info section */
  .swagger-ui .info .title {
    font-family: Georgia, serif !important;
    color: var(--mintflow-dark) !important;
  }

  /* Auth lock icon colour */
  .swagger-ui .authorization__btn svg { fill: var(--mintflow-green) !important; }

  /* Response code 200/201 */
  .swagger-ui .responses-inner .response-col_status { font-weight: 600; }
  .swagger-ui table.responses-table tr.response_200 .response-col_status,
  .swagger-ui table.responses-table tr.response_201 .response-col_status { color: var(--mintflow-green); }
  .swagger-ui table.responses-table tr.response_401 .response-col_status,
  .swagger-ui table.responses-table tr.response_403 .response-col_status { color: #A32D2D; }
  .swagger-ui table.responses-table tr.response_404 .response-col_status { color: #854F0B; }

  /* Try it out textarea */
  .swagger-ui textarea { border-radius: 6px !important; }

  /* Filter box */
  .swagger-ui .filter-container input {
    border-radius: 8px !important;
    border-color: var(--mintflow-green) !important;
  }

  /* Scheme/server selector */
  .swagger-ui .scheme-container { background: var(--mintflow-cream) !important; }
</style>
</head>""",
    )
    return HTMLResponse(branded)


@app.get("/redoc", include_in_schema=False)
async def redoc_ui():
    """ReDoc — clean, read-only API reference. Disabled in production."""
    if settings.is_production:
        return JSONResponse(status_code=404, content={"detail": "Not found"})

    return get_redoc_html(
        openapi_url="/openapi.json",
        title="Mintflow API — Reference",
        redoc_favicon_url="https://mintflow.app/favicon.ico",
        with_google_fonts=True,
    )


# ─── Routes ────────────────────────────────────────────────────────────────

API_PREFIX = "/v1"

app.include_router(auth_router,           prefix=API_PREFIX)
app.include_router(users_router,          prefix=API_PREFIX)
app.include_router(dashboard_router,      prefix=API_PREFIX)
app.include_router(insights_router,       prefix=API_PREFIX)
app.include_router(budgets_router,        prefix=API_PREFIX)
app.include_router(notifications_router,  prefix=API_PREFIX)
app.include_router(transactions_router,   prefix=API_PREFIX)
app.include_router(accounts_router,       prefix=API_PREFIX)
app.include_router(subscriptions_router,  prefix=API_PREFIX)


# ─── Health + root ─────────────────────────────────────────────────────────

@app.get(
    "/health",
    tags=["health"],
    summary="Health check",
    responses={200: {"description": "API is healthy.", "content": {"application/json": {"example": {"status": "ok", "version": "1.0.0", "env": "development"}}}}},
)
async def health():
    """
    Readiness probe used by Railway's health check and load balancers.
    No authentication required.
    """
    return {
        "status": "ok",
        "version": settings.APP_VERSION,
        "env": settings.APP_ENV,
    }


@app.get("/", include_in_schema=False)
async def root():
    return {
        "message": "Mintflow API",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "redoc": "/redoc",
        "openapi": "/openapi.json",
    }