"""
Accounts + Plaid endpoints — fully documented for Swagger/OpenAPI.
"""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import CurrentUser, require_feature
from app.db.session import get_db
from app.models.models import Account, User
from app.schemas.schemas import (
    AccountCreate,
    AccountRead,
    OKResponse,
    PlaidExchangeRequest,
    PlaidLinkTokenResponse,
)
from app.services.plaid_service import (
    create_link_token,
    exchange_public_token,
    remove_plaid_item,
    sync_transactions,
    verify_plaid_webhook,
)

router = APIRouter(prefix="/accounts", tags=["accounts"])

_BANK_EXAMPLE = {
    "id": "a1b2c3d4-0000-0000-0000-000000000002",
    "user_id": "b1c2d3e4-0000-0000-0000-000000000001",
    "name": "Chase Checking",
    "institution_name": "Chase",
    "account_type": "bank",
    "currency": "USD",
    "balance": "8420.00",
    "credit_limit": None,
    "outstanding_balance": None,
    "available_credit": None,
    "credit_utilization_pct": None,
    "statement_day": None,
    "due_day": None,
    "is_active": True,
    "last_synced_at": "2025-11-13T18:00:00Z",
    "created_at": "2025-10-01T09:00:00Z",
}

_CC_EXAMPLE = {
    "id": "e5f6a7b8-0000-0000-0000-000000000004",
    "user_id": "b1c2d3e4-0000-0000-0000-000000000001",
    "name": "Amex Gold",
    "institution_name": "American Express",
    "account_type": "credit_card",
    "currency": "USD",
    "balance": None,
    "credit_limit": "5000.00",
    "outstanding_balance": "1240.00",
    "available_credit": "3760.00",
    "credit_utilization_pct": 24.8,
    "statement_day": 15,
    "due_day": 5,
    "is_active": True,
    "last_synced_at": "2025-11-13T18:00:00Z",
    "created_at": "2025-10-01T09:00:00Z",
}

# Seed/Growth Plaid account cap when unlimited_accounts is false
_PLAID_ACCOUNT_CAP_GROWTH = 2


async def _enforce_account_limits(db: AsyncSession, user: User) -> None:
    if user.has_feature("unlimited_accounts"):
        return
    # Growth: max 2 Plaid-connected accounts; Seed: no Plaid (gate is bank_sync)
    result = await db.execute(
        select(func.count())
        .select_from(Account)
        .where(
            Account.user_id == user.id,
            Account.is_active == True,  # noqa: E712
            Account.plaid_account_id.is_not(None),
        )
    )
    plaid_count = result.scalar() or 0
    if plaid_count >= _PLAID_ACCOUNT_CAP_GROWTH:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Growth plan allows 2 linked bank accounts. Upgrade to Pro for unlimited.",
        )


@router.post(
    "",
    response_model=AccountRead,
    status_code=201,
    summary="Create a manual account",
    responses={
        201: {"description": "Account created.", "content": {"application/json": {"example": _BANK_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        422: {"description": "Validation error."},
    },
)
async def create_manual_account(
    payload: AccountCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a manual account — cash wallet, unsupported bank, or any account
    where Plaid is not available.
    """
    account = Account(
        user_id=current_user.id,
        name=payload.name,
        account_type=payload.account_type,
        currency=payload.currency,
        balance=payload.balance,
        credit_limit=payload.credit_limit,
        outstanding_balance=payload.outstanding_balance,
        statement_day=payload.statement_day,
        due_day=payload.due_day,
    )
    db.add(account)
    await db.flush()
    return AccountRead.model_validate(account)


@router.get(
    "",
    response_model=list[AccountRead],
    summary="List accounts",
    responses={
        200: {
            "description": "All active accounts.",
            "content": {"application/json": {"example": [_BANK_EXAMPLE, _CC_EXAMPLE]}},
        },
        401: {"description": "Missing or invalid JWT."},
    },
)
async def list_accounts(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Account)
        .where(
            Account.user_id == current_user.id,
            Account.is_active == True,  # noqa: E712
        )
        .order_by(Account.created_at)
    )
    return [AccountRead.model_validate(a) for a in result.scalars().all()]


@router.delete(
    "/{account_id}",
    response_model=OKResponse,
    summary="Unlink / deactivate an account",
    responses={
        200: {"description": "Account unlinked."},
        401: {"description": "Missing or invalid JWT."},
        404: {"description": "Account not found."},
    },
)
async def unlink_account(
    account_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Soft-deactivate a linked or manual account.
    For Plaid accounts, revokes the Item access token (best-effort).
    Transactions remain for history; the account no longer syncs.
    """
    result = await db.execute(
        select(Account).where(
            Account.id == account_id,
            Account.user_id == current_user.id,
            Account.is_active == True,  # noqa: E712
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    if account.plaid_access_token:
        await remove_plaid_item(account.plaid_access_token)
        account.plaid_access_token = None

    account.is_active = False
    await db.flush()
    return OKResponse(message="Account unlinked")


@router.post(
    "/plaid/link-token",
    response_model=PlaidLinkTokenResponse,
    summary="Create a Plaid Link token",
    responses={
        200: {
            "description": "Plaid Link token for use in the Flutter Plaid SDK.",
            "content": {
                "application/json": {
                    "example": {
                        "link_token": "link-sandbox-abc123",
                        "expiration": "2025-11-13T20:00:00Z",
                    }
                }
            },
        },
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Requires Growth or Pro tier."},
    },
)
async def get_plaid_link_token(
    current_user: Annotated[User, Depends(require_feature("bank_sync"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await _enforce_account_limits(db, current_user)
    token_data = await create_link_token(current_user.id)
    return PlaidLinkTokenResponse(**token_data)


@router.post(
    "/plaid/exchange",
    response_model=list[AccountRead],
    summary="Exchange Plaid public token",
    responses={
        200: {
            "description": "Connected accounts with initial sync complete.",
            "content": {"application/json": {"example": [_BANK_EXAMPLE, _CC_EXAMPLE]}},
        },
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Requires Growth or Pro tier."},
        422: {"description": "Invalid public token."},
    },
)
async def exchange_plaid_token(
    payload: PlaidExchangeRequest,
    current_user: Annotated[User, Depends(require_feature("bank_sync"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await _enforce_account_limits(db, current_user)
    accounts = await exchange_public_token(
        db, current_user.id, payload.public_token, payload.institution_name
    )
    # Cap after exchange if Growth would exceed (exchange can create multiple accounts)
    if not current_user.has_feature("unlimited_accounts"):
        result = await db.execute(
            select(func.count())
            .select_from(Account)
            .where(
                Account.user_id == current_user.id,
                Account.is_active == True,  # noqa: E712
                Account.plaid_account_id.is_not(None),
            )
        )
        if (result.scalar() or 0) > _PLAID_ACCOUNT_CAP_GROWTH:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Growth plan allows 2 linked bank accounts. Upgrade to Pro for unlimited.",
            )

    for account in accounts:
        if account.plaid_access_token:
            await sync_transactions(db, account)
    return [AccountRead.model_validate(a) for a in accounts]


@router.post(
    "/plaid/sync/{account_id}",
    response_model=dict,
    summary="Manually sync a Plaid account",
    responses={
        200: {
            "description": "Sync complete.",
            "content": {
                "application/json": {"example": {"added": 12, "modified": 2, "removed": 0}}
            },
        },
        401: {"description": "Missing or invalid JWT."},
        403: {"description": "Requires Growth or Pro tier."},
        404: {"description": "Account not found."},
        400: {"description": "Account is not Plaid-connected."},
    },
)
async def manual_sync(
    account_id: str,
    current_user: Annotated[User, Depends(require_feature("bank_sync"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(
        select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    if not account.plaid_access_token:
        raise HTTPException(status_code=400, detail="Account is not connected to Plaid")
    return await sync_transactions(db, account)


@router.post(
    "/plaid/webhook",
    summary="Plaid webhook receiver",
    include_in_schema=False,
)
async def plaid_webhook(request: Request, db: Annotated[AsyncSession, Depends(get_db)]):
    """
    Receive and process Plaid webhook events.
    Verifies Plaid-Verification JWT (ES256 + body SHA-256) per Plaid docs.
    """
    raw = await request.body()
    verification = request.headers.get("Plaid-Verification") or request.headers.get(
        "plaid-verification"
    )
    if not verify_plaid_webhook(verification, raw):
        raise HTTPException(status_code=401, detail="Invalid Plaid webhook signature")

    import json

    body = json.loads(raw.decode("utf-8"))
    webhook_type = body.get("webhook_type")
    webhook_code = body.get("webhook_code")
    item_id = body.get("item_id")

    if webhook_type == "TRANSACTIONS" and webhook_code == "SYNC_UPDATES_AVAILABLE":
        result = await db.execute(select(Account).where(Account.plaid_item_id == item_id))
        accounts = result.scalars().all()
        for account in accounts:
            if account.plaid_access_token:
                await sync_transactions(db, account)

    return {"received": True}
