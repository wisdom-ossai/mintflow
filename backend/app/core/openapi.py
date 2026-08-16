"""
Flowra API — OpenAPI / Swagger documentation configuration.

Centralises all spec metadata: tags, descriptions, contact, license,
server definitions, and security schemes. Keeps main.py clean.
"""
from fastapi.openapi.utils import get_openapi

# ─── Tag metadata ──────────────────────────────────────────────────────────
# Controls the order and descriptions of tag groups in Swagger UI.

TAGS_METADATA = [
    {
        "name": "auth",
        "description": (
            "Authentication via Supabase JWTs. All protected endpoints require "
            "a `Bearer <token>` header. Tokens are issued by Supabase Auth on "
            "signup/login and must be included in every subsequent request."
        ),
    },
    {
        "name": "users",
        "description": (
            "User profile management, onboarding completion, subscription status, "
            "and GDPR-compliant account deletion. The `/me` endpoints always "
            "operate on the authenticated user — no user ID required in the path."
        ),
    },
    {
        "name": "dashboard",
        "description": (
            "Aggregated monthly summary for the dashboard view. Returns income, "
            "spend, savings rate, needs/wants split, budget progress, and "
            "per-category breakdown. Credit card payments are automatically "
            "excluded from spend totals to prevent double-counting."
        ),
    },
    {
        "name": "transactions",
        "description": (
            "Core transaction CRUD. Supports manual entry and Plaid-synced "
            "transactions. On creation, the system checks the global merchant "
            "cache before calling Claude — reducing AI costs by ~65% at scale. "
            "Credit card bill payments are auto-detected and flagged to prevent "
            "double-counting in spend reports."
        ),
    },
    {
        "name": "accounts",
        "description": (
            "Bank accounts and credit cards. Manual accounts can be created "
            "freely. Plaid-connected accounts require Growth or Pro tier. "
            "Credit card accounts track outstanding balance, credit limit, "
            "utilization percentage, statement date, and due date."
        ),
    },
    {
        "name": "budgets",
        "description": (
            "Monthly and annual spending targets. An overall budget is created "
            "during onboarding. Per-category budgets require Growth or Pro tier. "
            "Budget progress is returned in the dashboard summary."
        ),
    },
    {
        "name": "insights",
        "description": (
            "AI-generated monthly narrative insights powered by Claude. "
            "Generated once per period and served from cache — never re-called "
            "on every screen open. Requires Growth or Pro tier. Users can "
            "submit thumbs-up/down feedback on each insight."
        ),
    },
    {
        "name": "notifications",
        "description": (
            "User notification preferences. Each notification type can be "
            "individually enabled or disabled. Time-of-day can be customised "
            "for the daily summary. Push delivery is handled by Firebase FCM."
        ),
    },
    {
        "name": "health",
        "description": "Health check and readiness probe endpoints. No auth required.",
    },
]

# ─── Security scheme ───────────────────────────────────────────────────────

SECURITY_SCHEMES = {
    "BearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": (
            "JWT issued by Supabase Auth. Obtain a token by calling "
            "`POST /auth/v1/token` on your Supabase project URL with "
            "`grant_type=password`. Include it as `Authorization: Bearer <token>`."
        ),
    }
}

# ─── Server definitions ────────────────────────────────────────────────────

SERVERS = [
    {
        "url": "http://localhost:8000",
        "description": "Local development",
    },
    {
        "url": "https://api.flowra.app",
        "description": "Production (Railway)",
    },
]

# ─── Full OpenAPI spec builder ─────────────────────────────────────────────

def build_openapi_schema(app):
    """
    Build a fully enriched OpenAPI schema with Flowra branding,
    server definitions, security schemes, and tag ordering.
    Called once and cached by FastAPI.
    """
    if app.openapi_schema:
        return app.openapi_schema

    schema = get_openapi(
        title="Flowra API",
        version="1.0.0",
        summary="Personal finance tracking and AI coaching API",
        description="""
## Overview

**Flowra** is a personal finance tracking platform that helps individuals
understand and control their money. This API powers the iOS, Android, and
Web clients.

---

## Authentication

All endpoints except `/health` and `/` require a valid **Supabase JWT**.

```
Authorization: Bearer <your-supabase-jwt>
```

Tokens are obtained via Supabase Auth (`/auth/v1/token`). They expire after
**1 hour** and must be refreshed using the Supabase client SDK.

---

## Subscription tiers

Feature access is gated by subscription tier:

| Feature | Seed (Free) | Growth ($6.99/mo) | Pro ($12.99/mo) |
|---|---|---|---|
| Manual transactions | ✓ | ✓ | ✓ |
| Bank/card sync (Plaid) | — | ✓ (2 accounts) | ✓ (unlimited) |
| AI categorization | — | ✓ | ✓ |
| Needs vs wants | — | ✓ | ✓ |
| Monthly AI insights | — | ✓ | ✓ |
| Credit utilization tracking | — | — | ✓ |
| Custom categories | — | — | ✓ |
| Receipt OCR | — | — | ✓ |
| CSV export | — | — | ✓ |

During the **7-day free trial**, all Pro features are unlocked.
After expiry, users revert to Seed unless they upgrade.

---

## Credit card handling

Flowra uses a **two-account model** for credit cards:

- Purchases made on a credit card → counted as **expenses** on the transaction date
- Credit card bill payments from a bank account → **excluded** from spend totals

This prevents double-counting. Every transaction has a `counts_as_spend`
field that reflects this logic. The `is_credit_card_payment` flag is
auto-detected using keyword matching on the merchant/description.

---

## AI cost optimisation

The Claude API is called only when needed:

1. **Merchant cache** — categorization results are cached globally by merchant name.
   The same merchant is never re-categorised. Reduces API calls by ~65% at scale.
2. **Insight caching** — monthly insights are generated once and served from the
   database. Stale insights are regenerated lazily on request.
3. **Notification batching** — AI notification copy is generated max once per user
   per day in a nightly batch job.

---

## Error responses

All errors follow this structure:

```json
{
  "detail": "Human-readable error message",
  "errors": [...]   // present on 422 validation errors only
}
```

| Status | Meaning |
|---|---|
| 400 | Bad request — invalid input |
| 401 | Unauthorised — missing or invalid JWT |
| 403 | Forbidden — feature requires higher subscription tier |
| 404 | Not found |
| 422 | Validation error — see `errors` field |
| 500 | Internal server error |

---

## Rate limiting

Requests are limited to **60 per minute** per authenticated user.
The limit is enforced at the API gateway layer on Railway.

---

## Contact & support

- **Website:** [flowra.app](https://flowra.app)
- **Support:** support@flowra.app
- **Status:** [status.flowra.app](https://status.flowra.app)
        """,
        contact={
            "name": "Flowra Support",
            "url": "https://flowra.app",
            "email": "support@flowra.app",
        },
        license_info={
            "name": "Proprietary",
            "url": "https://flowra.app/terms",
        },
        routes=app.routes,
        tags=TAGS_METADATA,
    )

    # Inject server definitions
    schema["servers"] = SERVERS

    # Inject security scheme
    schema.setdefault("components", {})
    schema["components"]["securitySchemes"] = SECURITY_SCHEMES

    # Apply global security requirement (all routes need BearerAuth by default)
    # Individual public routes override this with security=[]
    schema["security"] = [{"BearerAuth": []}]

    app.openapi_schema = schema
    return schema