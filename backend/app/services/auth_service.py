"""
Mintflow first-party auth service.
Argon2id passwords; JWT access + opaque refresh with rotation / reuse detection.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.password import (
    generate_opaque_token,
    hash_password,
    hash_token,
    needs_rehash,
    verify_password,
)
from app.core.security_jwt import create_access_token
from app.models.models import AuthSession, PasswordResetToken, SubscriptionTier, User, gen_uuid
from app.services.email_service import send_password_reset_email
from app.services.google_auth import verify_google_id_token

settings = get_settings()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _trial_ends() -> datetime:
    return _now() + timedelta(days=settings.TRIAL_DAYS)


async def _get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    result = await db.execute(select(User).where(User.email == email.lower().strip()))
    return result.scalar_one_or_none()


async def create_session(
    db: AsyncSession,
    user: User,
    *,
    user_agent: str | None = None,
    ip_address: str | None = None,
    family_id: str | None = None,
) -> tuple[str, AuthSession]:
    raw = generate_opaque_token()
    session = AuthSession(
        user_id=user.id,
        family_id=family_id or gen_uuid(),
        token_hash=hash_token(raw),
        expires_at=_now() + timedelta(days=settings.REFRESH_TOKEN_DAYS),
        user_agent=user_agent,
        ip_address=ip_address,
        last_used_at=_now(),
    )
    db.add(session)
    await db.flush()
    return raw, session


def issue_access(user: User) -> str:
    return create_access_token(user_id=str(user.id), email=user.email)


async def register_user(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    full_name: str | None,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> tuple[User, str, str]:
    email_n = email.lower().strip()
    if await _get_user_by_email(db, email_n):
        raise HTTPException(status_code=409, detail="An account with this email already exists")

    user = User(
        email=email_n,
        password_hash=hash_password(password),
        full_name=full_name.strip() if full_name else None,
        subscription_tier=SubscriptionTier.seed,
        trial_ends_at=_trial_ends(),
        email_verified_at=None,
    )
    db.add(user)
    await db.flush()
    refresh, _ = await create_session(db, user, user_agent=user_agent, ip_address=ip_address)
    return user, issue_access(user), refresh


async def login_user(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> tuple[User, str, str]:
    user = await _get_user_by_email(db, email)
    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    if not verify_password(user.password_hash, password):
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(password)
    refresh, _ = await create_session(db, user, user_agent=user_agent, ip_address=ip_address)
    return user, issue_access(user), refresh


async def login_or_register_google(
    db: AsyncSession,
    *,
    id_token_str: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> tuple[User, str, str]:
    claims = verify_google_id_token(id_token_str)
    google_sub = claims.get("sub")
    email = (claims.get("email") or "").lower().strip()
    if not google_sub or not email:
        raise HTTPException(status_code=400, detail="Google account is missing email")
    if not claims.get("email_verified", False):
        raise HTTPException(status_code=400, detail="Google email is not verified")

    result = await db.execute(select(User).where(User.google_sub == google_sub))
    user = result.scalar_one_or_none()
    if user is None:
        user = await _get_user_by_email(db, email)
        if user:
            user.google_sub = google_sub
            if not user.email_verified_at:
                user.email_verified_at = _now()
        else:
            user = User(
                email=email,
                google_sub=google_sub,
                full_name=claims.get("name"),
                avatar_url=claims.get("picture"),
                subscription_tier=SubscriptionTier.seed,
                trial_ends_at=_trial_ends(),
                email_verified_at=_now(),
            )
            db.add(user)
            await db.flush()
    else:
        if claims.get("name") and not user.full_name:
            user.full_name = claims.get("name")
        if claims.get("picture"):
            user.avatar_url = claims.get("picture")

    refresh, _ = await create_session(db, user, user_agent=user_agent, ip_address=ip_address)
    return user, issue_access(user), refresh


async def refresh_tokens(
    db: AsyncSession,
    *,
    raw_refresh: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> tuple[User, str, str]:
    th = hash_token(raw_refresh)
    result = await db.execute(select(AuthSession).where(AuthSession.token_hash == th))
    session = result.scalar_one_or_none()

    if session is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Reuse detection: already revoked/rotated
    if session.revoked_at is not None:
        await db.execute(
            update(AuthSession)
            .where(AuthSession.family_id == session.family_id)
            .values(revoked_at=_now())
        )
        raise HTTPException(
            status_code=401,
            detail="Refresh token reuse detected — all sessions for this device family were revoked",
        )

    if session.expires_at.replace(tzinfo=timezone.utc) < _now():
        session.revoked_at = _now()
        raise HTTPException(status_code=401, detail="Refresh token expired")

    user_result = await db.execute(select(User).where(User.id == session.user_id))
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Rotate
    session.revoked_at = _now()
    new_raw, new_session = await create_session(
        db,
        user,
        user_agent=user_agent,
        ip_address=ip_address,
        family_id=session.family_id,
    )
    session.replaced_by = new_session.id
    return user, issue_access(user), new_raw


async def logout(db: AsyncSession, *, raw_refresh: str | None) -> None:
    if not raw_refresh:
        return
    th = hash_token(raw_refresh)
    result = await db.execute(select(AuthSession).where(AuthSession.token_hash == th))
    session = result.scalar_one_or_none()
    if session and session.revoked_at is None:
        session.revoked_at = _now()


async def logout_all(db: AsyncSession, user_id: str) -> None:
    await db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=_now())
    )


async def change_password(
    db: AsyncSession,
    user: User,
    *,
    current_password: str,
    new_password: str,
) -> None:
    if not user.password_hash:
        raise HTTPException(
            status_code=400,
            detail="This account uses Google Sign-In. Set a password via forgot password, or continue with Google.",
        )
    if not verify_password(current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    user.password_hash = hash_password(new_password)
    await logout_all(db, str(user.id))


async def request_password_reset(db: AsyncSession, email: str) -> None:
    """Always succeeds from the caller's perspective (no email enumeration)."""
    user = await _get_user_by_email(db, email)
    if not user:
        return
    raw = generate_opaque_token()
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hash_token(raw),
            expires_at=_now() + timedelta(minutes=settings.PASSWORD_RESET_MINUTES),
        )
    )
    await db.flush()
    await send_password_reset_email(to=user.email, raw_token=raw)


async def reset_password(db: AsyncSession, *, raw_token: str, new_password: str) -> User:
    th = hash_token(raw_token)
    result = await db.execute(select(PasswordResetToken).where(PasswordResetToken.token_hash == th))
    row = result.scalar_one_or_none()
    if row is None or row.used_at is not None:
        raise HTTPException(status_code=400, detail="Invalid or expired reset link")
    if row.expires_at.replace(tzinfo=timezone.utc) < _now():
        raise HTTPException(status_code=400, detail="Invalid or expired reset link")

    user_result = await db.execute(select(User).where(User.id == row.user_id))
    user = user_result.scalar_one()
    user.password_hash = hash_password(new_password)
    row.used_at = _now()
    # Revoke all sessions after password change
    await logout_all(db, str(user.id))
    return user
