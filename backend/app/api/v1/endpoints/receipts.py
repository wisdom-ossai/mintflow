"""
Pro receipt OCR — upload image, extract fields via Claude vision, create expense txn.
Image bytes are not stored (PII minimization).
"""
from __future__ import annotations

from typing import Annotated, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import require_feature
from app.db.session import get_db
from app.models.models import (
    Transaction,
    TransactionSource,
    TransactionType,
    User,
)
from app.schemas.schemas import ReceiptOcrResult
from app.services.ocr_service import extract_receipt
from app.services.transaction_service import auto_categorize

router = APIRouter(prefix="/receipts", tags=["receipts"])

_ALLOWED = {"image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif", "application/octet-stream"}


@router.post(
    "/ocr",
    response_model=ReceiptOcrResult,
    status_code=201,
    summary="Scan a receipt and create a transaction",
)
async def ocr_receipt(
    current_user: Annotated[User, Depends(require_feature("receipt_ocr"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(..., description="Receipt image (JPEG/PNG/WebP, max 8MB)"),
    account_id: Optional[str] = Form(None),
):
    content_type = (file.content_type or "").lower()
    if content_type and content_type not in _ALLOWED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Upload a JPEG, PNG, or WebP receipt image.",
        )

    image_bytes = await file.read()
    try:
        extracted = await extract_receipt(
            image_bytes,
            filename=file.filename,
            content_type=file.content_type,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        ) from e

    if extracted["amount"] <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Could not find a total on this receipt. Try a clearer photo.",
        )

    txn = Transaction(
        user_id=current_user.id,
        account_id=account_id,
        amount=extracted["amount"],
        transaction_type=TransactionType.expense,
        description=extracted.get("description")
        or (extracted.get("merchant_name") and f"Receipt · {extracted['merchant_name']}")
        or "Receipt scan",
        merchant_name=extracted.get("merchant_name"),
        date=extracted["date"],
        source=TransactionSource.ocr,
        ai_confidence=extracted["confidence"],
    )
    db.add(txn)
    await db.flush()

    category_name = None
    is_need = None
    try:
        ai_result = await auto_categorize(
            db,
            str(current_user.id),
            txn.merchant_name,
            txn.amount,
            allow_ai=current_user.has_feature("ai_categorization"),
        )
        if ai_result.get("category") is not None:
            txn.category_id = ai_result["category"].id
            category_name = ai_result["category"].name
        if ai_result.get("is_need") is not None:
            txn.is_need = ai_result["is_need"]
            is_need = ai_result["is_need"]
        if ai_result.get("ai_categorized"):
            txn.ai_categorized = True
            if ai_result.get("ai_confidence") is not None:
                txn.ai_confidence = ai_result["ai_confidence"]
        await db.flush()
    except Exception:
        # OCR still succeeds even if categorization fails
        pass

    await db.refresh(txn)
    return ReceiptOcrResult(
        merchant_name=txn.merchant_name,
        amount=txn.amount,
        date=txn.date,
        description=txn.description,
        transaction_id=str(txn.id),
        category_name=category_name,
        is_need=is_need,
        confidence=float(extracted["confidence"]),
    )
