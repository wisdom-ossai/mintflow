"""
Pydantic v2 schemas for all API request/response models.
"""
from __future__ import annotations
from datetime import datetime
from decimal import Decimal
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.models.models import (
    AccountType, BudgetPeriod, InsightPeriod,
    NotificationType, SubscriptionTier,
    TransactionSource, TransactionType,
)


# ─── Shared ────────────────────────────────────────────────────────────────

class OKResponse(BaseModel):
    ok: bool = True
    message: str = "Success"


# ─── Auth ──────────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    password: str = Field(min_length=8, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(min_length=20)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20)


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=20)
    password: str = Field(min_length=8, max_length=128)


class AuthTokensResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: "UserRead"


# ─── Users ─────────────────────────────────────────────────────────────────

class UserRead(BaseModel):
    id: str
    email: str
    full_name: Optional[str]
    avatar_url: Optional[str]
    subscription_tier: SubscriptionTier
    trial_ends_at: Optional[datetime]
    locale: str
    currency: str
    monthly_income: Optional[Decimal]
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    locale: Optional[str] = None
    currency: Optional[str] = None
    monthly_income: Optional[Decimal] = None
    firebase_token: Optional[str] = None


class OnboardingPayload(BaseModel):
    full_name: Optional[str] = None
    monthly_income: Optional[Decimal] = None
    monthly_spending_target: Optional[Decimal] = None
    currency: str = "USD"
    locale: str = "en-US"


# ─── Accounts ──────────────────────────────────────────────────────────────

class AccountCreate(BaseModel):
    name: str = Field(max_length=255)
    account_type: AccountType
    currency: str = "USD"
    balance: Optional[Decimal] = None
    credit_limit: Optional[Decimal] = None
    outstanding_balance: Optional[Decimal] = None
    statement_day: Optional[int] = Field(None, ge=1, le=31)
    due_day: Optional[int] = Field(None, ge=1, le=31)

    @field_validator("credit_limit", "outstanding_balance")
    @classmethod
    def credit_fields_only_for_cc(cls, v, info):
        return v


class AccountRead(BaseModel):
    id: str
    user_id: str
    name: str
    institution_name: Optional[str]
    account_type: AccountType
    currency: str
    balance: Optional[Decimal]
    credit_limit: Optional[Decimal]
    outstanding_balance: Optional[Decimal]
    available_credit: Optional[Decimal]
    credit_utilization_pct: Optional[float]
    statement_day: Optional[int]
    due_day: Optional[int]
    is_active: bool
    last_synced_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class PlaidLinkTokenResponse(BaseModel):
    link_token: str
    expiration: str


class PlaidExchangeRequest(BaseModel):
    public_token: str
    institution_name: Optional[str] = None


# ─── Categories ────────────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str = Field(max_length=100)
    icon: Optional[str] = None
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")


class CategoryRead(BaseModel):
    id: str
    user_id: Optional[str]
    name: str
    icon: Optional[str]
    color: Optional[str]
    is_custom: bool

    model_config = {"from_attributes": True}


# ─── Transactions ──────────────────────────────────────────────────────────

class TransactionCreate(BaseModel):
    amount: Decimal = Field(gt=0, description="Positive transaction amount.")
    transaction_type: TransactionType = Field(TransactionType.expense, description="income | expense | credit_payment | transfer")
    description: Optional[str] = Field(None, max_length=500, description="Raw bank description.")
    merchant_name: Optional[str] = Field(None, max_length=255, description="Merchant name used for AI categorization.")
    date: datetime = Field(description="Transaction date (ISO 8601).")
    account_id: Optional[str] = Field(None, description="Account UUID.")
    category_id: Optional[str] = Field(None, description="Category UUID. If omitted, AI auto-categorizes.")
    is_need: Optional[bool] = Field(None, description="Override need/want. If omitted, AI decides.")
    notes: Optional[str] = Field(None, description="Optional user note.")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {"summary": "Grocery purchase", "value": {"amount": 84.20, "transaction_type": "expense", "merchant_name": "Whole Foods Market", "description": "WHOLE FOODS MARKET #1234", "date": "2025-11-13T19:32:00Z", "account_id": "a1b2c3d4-0000-0000-0000-000000000002", "notes": "Weekly grocery run"}},
                {"summary": "Salary income", "value": {"amount": 5400.00, "transaction_type": "income", "merchant_name": "Employer Inc", "description": "DIRECT DEPOSIT", "date": "2025-11-01T09:00:00Z", "account_id": "a1b2c3d4-0000-0000-0000-000000000002"}},
                {"summary": "Cash spending", "value": {"amount": 12.00, "transaction_type": "expense", "merchant_name": "Street vendor", "date": "2025-11-13T13:00:00Z", "is_need": False, "notes": "Lunch"}},
            ]
        }
    }

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v):
        return round(v, 2)


class TransactionUpdate(BaseModel):
    description: Optional[str] = None
    merchant_name: Optional[str] = None
    category_id: Optional[str] = None
    is_need: Optional[bool] = None
    notes: Optional[str] = None
    date: Optional[datetime] = None


class TransactionRead(BaseModel):
    id: str
    user_id: str
    account_id: Optional[str]
    category_id: Optional[str]
    category: Optional[CategoryRead]
    amount: Decimal
    transaction_type: TransactionType
    is_need: Optional[bool]
    description: Optional[str]
    merchant_name: Optional[str]
    date: datetime
    source: TransactionSource
    is_credit_card_payment: bool
    is_recurring: bool
    notes: Optional[str]
    ai_categorized: bool
    counts_as_spend: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class TransactionListResponse(BaseModel):
    transactions: list[TransactionRead]
    total: int
    page: int
    page_size: int
    total_pages: int


class TransactionFilters(BaseModel):
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    transaction_type: Optional[TransactionType] = None
    category_id: Optional[str] = None
    account_id: Optional[str] = None
    is_need: Optional[bool] = None
    search: Optional[str] = None
    page: int = Field(1, ge=1)
    page_size: int = Field(20, ge=1, le=100)


# ─── Budgets ───────────────────────────────────────────────────────────────

class BudgetCreate(BaseModel):
    amount: Decimal = Field(gt=0)
    period: BudgetPeriod = BudgetPeriod.monthly
    category_id: Optional[str] = None  # null = overall budget
    rollover: bool = False


class BudgetRead(BaseModel):
    id: str
    user_id: str
    category_id: Optional[str]
    category: Optional[CategoryRead]
    amount: Decimal
    period: BudgetPeriod
    rollover: bool
    is_active: bool

    model_config = {"from_attributes": True}


class BudgetWithProgress(BudgetRead):
    spent: Decimal
    remaining: Decimal
    pct_used: float
    is_over: bool


# ─── Insights ──────────────────────────────────────────────────────────────

class InsightItem(BaseModel):
    type: str               # "positive" | "warning" | "info" | "recommendation"
    title: str
    body: str
    action_label: Optional[str] = None
    action_type: Optional[str] = None  # "set_budget" | "review_subscriptions" | etc.


class InsightContent(BaseModel):
    summary: str
    insights: list[InsightItem]
    recommendations: list[InsightItem]
    generated_at: str


class InsightRead(BaseModel):
    id: str
    period: InsightPeriod
    period_key: str
    content: InsightContent
    thumbs_up: Optional[bool]
    generated_at: datetime

    model_config = {"from_attributes": True}


class InsightFeedback(BaseModel):
    thumbs_up: bool


# ─── Dashboard ─────────────────────────────────────────────────────────────

class SpendingByCategory(BaseModel):
    category_id: Optional[str]
    category_name: str
    category_color: Optional[str]
    total: Decimal
    pct_of_total: float
    is_need: Optional[bool]
    transaction_count: int


class DashboardSummary(BaseModel):
    period_key: str             # "2025-11"
    total_income: Decimal
    total_spent: Decimal        # excludes CC payments
    total_saved: Decimal
    savings_rate_pct: float
    needs_total: Decimal
    wants_total: Decimal
    needs_pct: float
    wants_pct: float
    budget_amount: Optional[Decimal]
    budget_pct_used: Optional[float]
    budget_remaining: Optional[Decimal]
    days_in_period: int
    days_elapsed: int
    days_remaining: int
    projected_spend: Optional[Decimal]
    spending_by_category: list[SpendingByCategory]
    top_insight: Optional[str]   # one-liner from AI for dashboard card


# ─── Notifications ─────────────────────────────────────────────────────────

class NotificationPrefUpdate(BaseModel):
    enabled: bool
    time_of_day: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")


class NotificationPrefRead(BaseModel):
    notification_type: NotificationType
    enabled: bool
    time_of_day: Optional[str]

    model_config = {"from_attributes": True}


# ─── Subscriptions ─────────────────────────────────────────────────────────

class RevenueCatWebhookEvent(BaseModel):
    event: dict[str, Any]


class SubscriptionStatusRead(BaseModel):
    tier: SubscriptionTier
    trial_ends_at: Optional[datetime]
    is_trial_active: bool
    effective_tier: SubscriptionTier