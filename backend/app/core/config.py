from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    APP_ENV: str = "development"
    APP_NAME: str = "Flowra API"
    APP_VERSION: str = "1.0.0"
    SECRET_KEY: str
    ALLOWED_ORIGINS: str = "http://localhost:4444"
    SCHEDULER_ENABLED: bool = True
    TRIAL_DAYS: int = 7
    APP_PUBLIC_URL: str = "https://flowra.app"
    # Deep link base for mobile password reset (Flutter scheme)
    APP_DEEP_LINK_RESET: str = "flowra://reset-password"

    # Database (Railway Postgres in prod; local docker-compose for dev)
    DATABASE_URL: str

    # JWT / sessions
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_MINUTES: int = 15
    REFRESH_TOKEN_DAYS: int = 30
    PASSWORD_RESET_MINUTES: int = 60

    # Google Sign-In — Web client ID used as audience for ID token verify
    GOOGLE_CLIENT_ID: str = ""
    # Optional extra audiences (iOS/Android client IDs)
    GOOGLE_CLIENT_IDS: str = ""

    # Resend transactional email
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "Flowra <noreply@flowra.app>"

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

    # RevenueCat
    REVENUECAT_WEBHOOK_SECRET: str = ""
    REVENUECAT_ENTITLEMENT_GROWTH: str = "growth"
    REVENUECAT_ENTITLEMENT_PRO: str = "pro"

    # Stripe (unused — prefer RevenueCat for mobile IAP)
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""

    # Sentry
    SENTRY_DSN: str = ""

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
    def google_audiences(self) -> List[str]:
        ids = [self.GOOGLE_CLIENT_ID.strip()] if self.GOOGLE_CLIENT_ID.strip() else []
        for part in self.GOOGLE_CLIENT_IDS.split(","):
            p = part.strip()
            if p and p not in ids:
                ids.append(p)
        return ids


@lru_cache
def get_settings() -> Settings:
    return Settings()
