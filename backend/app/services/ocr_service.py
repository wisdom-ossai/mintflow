"""
Receipt OCR via Claude vision. Images are processed in-memory and discarded —
only extracted fields are persisted on the resulting transaction (PII minimization).
"""
from __future__ import annotations

import base64
import json
import logging
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Optional

import anthropic

from app.core.config import get_settings
from app.services.ai_service import get_anthropic_client

logger = logging.getLogger(__name__)
settings = get_settings()

_OCR_SYSTEM = """You extract purchase data from a receipt image for a personal finance app.
Respond ONLY with JSON (no markdown):
{
  "merchant_name": string|null,
  "amount": number,
  "date": "YYYY-MM-DD" or null,
  "description": string|null,
  "confidence": number between 0 and 1
}
Rules:
- amount is the total charged (not subtotal). Use the largest clear total if ambiguous.
- Do not invent merchants or amounts you cannot read.
- If amount is unreadable, use 0 and confidence below 0.3.
- Ignore tip lines unless they are included in a clearly marked grand total.
- Never include card numbers, account numbers, or full addresses in any field."""


def _media_type(filename: str | None, content_type: str | None) -> str:
    if content_type in ("image/jpeg", "image/png", "image/gif", "image/webp"):
        return content_type
    name = (filename or "").lower()
    if name.endswith(".png"):
        return "image/png"
    if name.endswith(".gif"):
        return "image/gif"
    if name.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


async def extract_receipt(
    image_bytes: bytes,
    filename: str | None = None,
    content_type: str | None = None,
) -> dict:
    """
    Returns merchant_name, amount (Decimal), date (datetime), description, confidence.
    """
    if len(image_bytes) > 8 * 1024 * 1024:
        raise ValueError("Receipt image must be 8MB or smaller")
    if not image_bytes:
        raise ValueError("Empty receipt image")

    client = get_anthropic_client()
    b64 = base64.standard_b64encode(image_bytes).decode("ascii")
    media = _media_type(filename, content_type)

    try:
        response = client.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=300,
            system=_OCR_SYSTEM,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media,
                                "data": b64,
                            },
                        },
                        {
                            "type": "text",
                            "text": "Extract the receipt total and merchant.",
                        },
                    ],
                }
            ],
        )
        raw = response.content[0].text.strip()
        # Tolerate accidental markdown fences
        if raw.startswith("```"):
            raw = raw.strip("`")
            if raw.startswith("json"):
                raw = raw[4:].strip()
        data = json.loads(raw)
    except (json.JSONDecodeError, KeyError, IndexError, anthropic.APIError) as e:
        logger.error("Receipt OCR failed: %s", e)
        raise ValueError("Could not read this receipt. Try a clearer photo.") from e

    try:
        amount = Decimal(str(data.get("amount", 0)))
    except (InvalidOperation, TypeError) as e:
        raise ValueError("Could not parse receipt amount") from e
    if amount < 0:
        amount = abs(amount)

    date_raw = data.get("date")
    if date_raw:
        try:
            parsed = datetime.fromisoformat(str(date_raw).replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            txn_date = parsed
        except ValueError:
            txn_date = datetime.now(timezone.utc)
    else:
        txn_date = datetime.now(timezone.utc)

    confidence = float(data.get("confidence") or 0.5)
    merchant = data.get("merchant_name")
    if merchant is not None:
        merchant = str(merchant).strip()[:255] or None

    description = data.get("description")
    if description is not None:
        description = str(description).strip()[:500] or None

    return {
        "merchant_name": merchant,
        "amount": amount,
        "date": txn_date,
        "description": description,
        "confidence": max(0.0, min(1.0, confidence)),
    }
