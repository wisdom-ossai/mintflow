"""
RevenueCat webhook — updates users.subscription_tier from entitlements.
Never trust the client to set tier.
"""
from __future__ import annotations

import hmac
import logging
from typing import Annotated, Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import get_db
from app.models.models import SubscriptionTier, User
from app.schemas.schemas import OKResponse

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])

# Events that should refresh entitlements from the payload.
_ACTIVE_EVENTS = {
    "INITIAL_PURCHASE",
    "RENEWAL",
    "PRODUCT_CHANGE",
    "UNCANCELLATION",
    "NON_RENEWING_PURCHASE",
}
_DOWNGRADE_EVENTS = {
    "EXPIRATION",
    "CANCELLATION",  # may still be entitled until period end — check entitlements
}


def _tier_from_entitlements(entitlements: dict[str, Any] | None) -> SubscriptionTier:
    """
    Map RevenueCat entitlement identifiers → Mintflow tiers.
    Pro wins if both present.
    """
    if not entitlements:
        return SubscriptionTier.seed
    ids = {str(k).lower() for k in entitlements.keys()}
    pro_id = settings.REVENUECAT_ENTITLEMENT_PRO.lower()
    growth_id = settings.REVENUECAT_ENTITLEMENT_GROWTH.lower()
    if pro_id in ids:
        return SubscriptionTier.pro
    if growth_id in ids:
        return SubscriptionTier.growth
    # Fallback: product_id heuristics
    for key in ids:
        if "pro" in key:
            return SubscriptionTier.pro
        if "growth" in key:
            return SubscriptionTier.growth
    return SubscriptionTier.seed


def _verify_authorization(authorization: Optional[str]) -> None:
    expected = settings.REVENUECAT_WEBHOOK_SECRET
    if not expected:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="RevenueCat webhook not configured",
        )
    provided = authorization or ""
    # Dashboard may store either raw secret or "Bearer <secret>"
    if not expected.startswith("Bearer ") and provided.startswith("Bearer "):
        # Compare Bearer token portion to configured raw secret
        token = provided[7:].strip()
        if not hmac.compare_digest(token, expected):
            raise HTTPException(status_code=401, detail="Invalid webhook authorization")
        return
    if not hmac.compare_digest(provided, expected) and not hmac.compare_digest(
        provided, f"Bearer {expected}"
    ):
        raise HTTPException(status_code=401, detail="Invalid webhook authorization")


@router.post(
    "/webhook",
    response_model=OKResponse,
    include_in_schema=False,
    status_code=200,
)
async def revenuecat_webhook(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[Optional[str], Header()] = None,
):
    """
    RevenueCat server notification. Auth via dashboard Authorization header
    (stored as REVENUECAT_WEBHOOK_SECRET). Maps entitlements → subscription_tier.
    """
    _verify_authorization(authorization)
    body = await request.json()
    event = body.get("event") or body
    event_type = event.get("type") or body.get("type")
    app_user_id = (
        event.get("app_user_id")
        or event.get("original_app_user_id")
        or body.get("app_user_id")
    )
    if not app_user_id:
        logger.warning("RevenueCat webhook missing app_user_id: %s", event_type)
        return OKResponse(message="ignored")

    result = await db.execute(select(User).where(User.id == str(app_user_id)))
    user = result.scalar_one_or_none()
    if user is None:
        # Also try email lookup is not available — RC uses Mintflow user id as app_user_id
        logger.info("RevenueCat webhook for unknown user %s", app_user_id)
        return OKResponse(message="user not found")

    entitlements = (
        event.get("entitlements")
        or (event.get("subscriber") or {}).get("entitlements")
        or body.get("entitlements")
    )

    if event_type in _ACTIVE_EVENTS or event_type in _DOWNGRADE_EVENTS or entitlements:
        new_tier = _tier_from_entitlements(entitlements)
        # On EXPIRATION with empty entitlements → Seed
        if event_type == "EXPIRATION" and not entitlements:
            new_tier = SubscriptionTier.seed
        if user.subscription_tier != new_tier:
            logger.info(
                "RevenueCat: user %s tier %s → %s (%s)",
                user.id,
                user.subscription_tier,
                new_tier,
                event_type,
            )
            user.subscription_tier = new_tier

    return OKResponse(message="ok")
