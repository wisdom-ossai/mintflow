"""
JWT authentication middleware.
Validates Supabase-issued JWTs and provisions Flowra User rows on first request.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Annotated, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import get_db
from app.models.models import SubscriptionTier, User

settings = get_settings()
bearer_scheme = HTTPBearer(auto_error=True)


async def _provision_user(
    db: AsyncSession,
    user_id: str,
    email: Optional[str],
    full_name: Optional[str] = None,
) -> User:
    """
    Create the Flowra User row matching Supabase Auth `sub`.
    Starts a card-free Pro trial (TRIAL_DAYS). Idempotent on concurrent first hits.
    """
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing email claim; cannot provision user",
            headers={"WWW-Authenticate": "Bearer"},
        )

    trial_ends = datetime.now(timezone.utc) + timedelta(days=settings.TRIAL_DAYS)
    user = User(
        id=user_id,
        email=email.lower().strip(),
        full_name=full_name,
        subscription_tier=SubscriptionTier.seed,
        trial_ends_at=trial_ends,
    )
    db.add(user)
    await db.flush()
    return user


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    """
    Decode JWT with the Supabase JWT secret, look up (or provision) User.
    `sub` == `users.id`.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
            options={"verify_aud": True},
        )
        user_id: Optional[str] = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        email = payload.get("email")
        meta = payload.get("user_metadata") or {}
        full_name = meta.get("full_name") or meta.get("name")
        user = await _provision_user(db, user_id, email, full_name)

    return user


def require_feature(feature: str):
    """
    Dependency factory — gates a route behind a subscription feature.
    Usage: Depends(require_feature("bank_sync"))
    """

    async def _check(
        current_user: Annotated[User, Depends(get_current_user)],
    ) -> User:
        if not current_user.has_feature(feature):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Feature '{feature}' requires a higher subscription tier.",
            )
        return current_user

    return _check


CurrentUser = Annotated[User, Depends(get_current_user)]
