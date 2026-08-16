"""
Transactions endpoints — fully documented for Swagger/OpenAPI.
"""
from typing import Annotated, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.auth import CurrentUser, get_current_user
from app.db.session import get_db
from app.models.models import Transaction
from app.schemas.schemas import (
    TransactionCreate, TransactionUpdate, TransactionRead,
    TransactionFilters, TransactionListResponse, OKResponse,
)
from app.services.transaction_service import (
    create_transaction, list_transactions,
)

router = APIRouter(prefix="/transactions", tags=["transactions"])

_TX_EXAMPLE = {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "user_id": "b1c2d3e4-0000-0000-0000-000000000001",
    "account_id": "a1b2c3d4-0000-0000-0000-000000000002",
    "category_id": "c1d2e3f4-0000-0000-0000-000000000003",
    "category": {"id": "c1d2e3f4-0000-0000-0000-000000000003", "name": "Groceries", "icon": "shopping_cart", "color": "#2EAD6A", "is_custom": False},
    "amount": "84.20",
    "transaction_type": "expense",
    "is_need": True,
    "description": "WHOLE FOODS MARKET #1234",
    "merchant_name": "Whole Foods Market",
    "date": "2025-11-13T19:32:00Z",
    "source": "manual",
    "is_credit_card_payment": False,
    "is_recurring": False,
    "notes": "Weekly grocery run",
    "ai_categorized": True,
    "counts_as_spend": True,
    "created_at": "2025-11-13T19:32:01Z",
}

_LIST_EXAMPLE = {
    "transactions": [_TX_EXAMPLE],
    "total": 142, "page": 1, "page_size": 20, "total_pages": 8,
}


@router.post(
    "",
    response_model=TransactionRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a transaction",
    responses={
        201: {"description": "Transaction created and auto-categorized.", "content": {"application/json": {"example": _TX_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        422: {"description": "Validation error."},
    },
)
async def add_transaction(
    payload: TransactionCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Create a new transaction via manual entry.

    **Auto-categorization flow:**
    1. `category_id` provided → use directly, skip AI.
    2. `merchant_name` present → check global merchant cache.
    3. Cache hit → apply cached category + `is_need` (no API cost).
    4. Cache miss → call Claude API → cache result → apply.

    **Credit card payment detection:**
    Keywords like `"autopay"`, `"online payment"`, `"card payment"` in
    `description` or `merchant_name` trigger `is_credit_card_payment: true`,
    excluding the transaction from spend totals to prevent double-counting.

    **Tier:** All tiers. AI categorization on Growth/Pro only.
    """
    tx = await create_transaction(
        db,
        current_user.id,
        payload,
        allow_ai=current_user.has_feature("ai_categorization"),
    )
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Transaction).options(selectinload(Transaction.category)).where(Transaction.id == tx.id)
    )
    return TransactionRead.model_validate(result.scalar_one())


@router.get(
    "",
    response_model=TransactionListResponse,
    summary="List transactions",
    responses={
        200: {"description": "Paginated list, newest first.", "content": {"application/json": {"example": _LIST_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
    },
)
async def get_transactions(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: Optional[datetime] = Query(None, description="Filter on or after this date (ISO 8601).", example="2025-11-01T00:00:00Z"),
    end_date: Optional[datetime] = Query(None, description="Filter on or before this date (ISO 8601).", example="2025-11-30T23:59:59Z"),
    transaction_type: Optional[str] = Query(None, description="One of: `income`, `expense`, `credit_payment`, `transfer`.", example="expense"),
    category_id: Optional[str] = Query(None, description="Filter by category UUID."),
    account_id: Optional[str] = Query(None, description="Filter by account UUID."),
    is_need: Optional[bool] = Query(None, description="Filter needs (`true`) or wants (`false`). Omit for both."),
    search: Optional[str] = Query(None, description="Search `merchant_name` and `description`.", example="Whole Foods"),
    page: int = Query(1, ge=1, description="Page number (1-based)."),
    page_size: int = Query(20, ge=1, le=100, description="Results per page (max 100)."),
):
    """
    Paginated, filterable transaction list ordered newest first.

    Credit card payments (`is_credit_card_payment: true`) are included
    but marked `counts_as_spend: false` for correct client rendering.

    **Common combos:** monthly view (`start_date` + `end_date`),
    wants only (`is_need=false`), search (`search=netflix`).
    """
    filters = TransactionFilters(
        start_date=start_date, end_date=end_date,
        transaction_type=transaction_type, category_id=category_id,
        account_id=account_id, is_need=is_need,
        search=search, page=page, page_size=page_size,
    )
    return await list_transactions(db, current_user.id, filters)


@router.get(
    "/{transaction_id}",
    response_model=TransactionRead,
    summary="Get a transaction",
    responses={
        200: {"description": "Transaction detail.", "content": {"application/json": {"example": _TX_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        404: {"description": "Not found or belongs to another user."},
    },
)
async def get_transaction(
    transaction_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Retrieve a single transaction by ID.

    Returns `404` whether the transaction is missing **or** belongs to
    another user — no data leakage about other users.
    """
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Transaction).options(selectinload(Transaction.category))
        .where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return TransactionRead.model_validate(tx)


@router.patch(
    "/{transaction_id}",
    response_model=TransactionRead,
    summary="Update a transaction",
    responses={
        200: {"description": "Updated transaction.", "content": {"application/json": {"example": _TX_EXAMPLE}}},
        401: {"description": "Missing or invalid JWT."},
        404: {"description": "Transaction not found."},
        422: {"description": "Validation error."},
    },
)
async def update_transaction(
    transaction_id: str,
    payload: TransactionUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Partially update a transaction (PATCH — only sent fields are modified).

    **Common uses:** correct category `{"category_id": "..."}`,
    override needs/wants `{"is_need": false}`,
    add a note `{"notes": "Business lunch"}`,
    fix date `{"date": "2025-11-10T12:00:00Z"}`.
    """
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Transaction).options(selectinload(Transaction.category))
        .where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(tx, field, value)
    return TransactionRead.model_validate(tx)


@router.delete(
    "/{transaction_id}",
    response_model=OKResponse,
    summary="Delete a transaction",
    responses={
        200: {"description": "Deleted.", "content": {"application/json": {"example": {"ok": True, "message": "Transaction deleted"}}}},
        401: {"description": "Missing or invalid JWT."},
        404: {"description": "Transaction not found."},
    },
)
async def delete_transaction(
    transaction_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Permanently delete a transaction.

    **Note:** Plaid-synced transactions will reappear on the next sync.
    To suppress permanently, update with a note or use the block-list
    feature (roadmap).
    """
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    await db.delete(tx)
    return OKResponse(message="Transaction deleted")