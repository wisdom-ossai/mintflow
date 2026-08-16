from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # App
    APP_ENV: str = "development"
    APP_NAME: str = "Flowra API"
    APP_VERSION: str = "1.0.0"
    SECRET_KEY: str
    ALLOWED_ORIGINS: str = "http://localhost:4444"
    # In-process APScheduler — enable on exactly one process (workers=1 or a job service).
    SCHEDULER_ENABLED: bool = True
    TRIAL_DAYS: int = 7

    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    # JWT secret from Supabase Dashboard → Settings → API → JWT Secret (not the anon key).
    SUPABASE_JWT_SECRET: str = ""
    DATABASE_URL: str

    # Plaid
    PLAID_CLIENT_ID: str
    PLAID_SECRET: str
    PLAID_ENV: str = "sandbox"
    PLAID_WEBHOOK_URL: str = ""

    # Anthropic
    ANTHROPIC_API_KEY: str
    CLAUDE_MODEL: str = "claude-sonnet-4-20250514"

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"

    # RevenueCat — Authorization header value configured in the RC dashboard webhook.
    REVENUECAT_WEBHOOK_SECRET: str = ""
    # Entitlement identifiers in RevenueCat (map → subscription_tier).
    REVENUECAT_ENTITLEMENT_GROWTH: str = "growth"
    REVENUECAT_ENTITLEMENT_PRO: str = "pro"

    # Stripe (unused — prefer RevenueCat for mobile IAP)
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""

    # Sentry
    SENTRY_DSN: str = ""

    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = 60

    @property
    def allowed_origins_list(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"

    @property
    def is_development(self) -> bool:
        return self.APP_ENV == "development"

    @property
    def jwt_secret(self) -> str:
        """Prefer dedicated JWT secret; fall back to anon key only in local dev."""
        if self.SUPABASE_JWT_SECRET:
            return self.SUPABASE_JWT_SECRET
        if self.is_production:
            raise RuntimeError(
                "SUPABASE_JWT_SECRET is required in production "
                "(Supabase Dashboard → Settings → API → JWT Secret)."
            )
        return self.SUPABASE_ANON_KEY


@lru_cache
def get_settings() -> Settings:
    return Settings()
