"""
Auth endpoints — signup, login, refresh, logout, Google, password reset.
"""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.schemas.schemas import (
    AuthTokensResponse,
    ForgotPasswordRequest,
    GoogleAuthRequest,
    LogoutRequest,
    OKResponse,
    RefreshRequest,
    ResetPasswordRequest,
    UserCreate,
    UserLogin,
    UserRead,
)
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _client_meta(request: Request) -> tuple[str | None, str | None]:
    ua = request.headers.get("user-agent")
    ip = request.client.host if request.client else None
    return ua, ip


@router.post(
    "/signup",
    response_model=AuthTokensResponse,
    status_code=201,
    summary="Create account",
)
async def signup(
    payload: UserCreate,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ua, ip = _client_meta(request)
    user, access, refresh = await auth_service.register_user(
        db,
        email=str(payload.email),
        password=payload.password,
        full_name=payload.full_name,
        user_agent=ua,
        ip_address=ip,
    )
    return AuthTokensResponse(
        access_token=access,
        refresh_token=refresh,
        user=UserRead.model_validate(user),
    )


@router.post("/login", response_model=AuthTokensResponse, summary="Email login")
async def login(
    payload: UserLogin,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ua, ip = _client_meta(request)
    user, access, refresh = await auth_service.login_user(
        db,
        email=str(payload.email),
        password=payload.password,
        user_agent=ua,
        ip_address=ip,
    )
    return AuthTokensResponse(
        access_token=access,
        refresh_token=refresh,
        user=UserRead.model_validate(user),
    )


@router.post("/google", response_model=AuthTokensResponse, summary="Google Sign-In")
async def google_login(
    payload: GoogleAuthRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ua, ip = _client_meta(request)
    try:
        user, access, refresh = await auth_service.login_or_register_google(
            db,
            id_token_str=payload.id_token,
            user_agent=ua,
            ip_address=ip,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return AuthTokensResponse(
        access_token=access,
        refresh_token=refresh,
        user=UserRead.model_validate(user),
    )


@router.post("/refresh", response_model=AuthTokensResponse, summary="Rotate tokens")
async def refresh_session(
    payload: RefreshRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ua, ip = _client_meta(request)
    user, access, refresh = await auth_service.refresh_tokens(
        db,
        raw_refresh=payload.refresh_token,
        user_agent=ua,
        ip_address=ip,
    )
    return AuthTokensResponse(
        access_token=access,
        refresh_token=refresh,
        user=UserRead.model_validate(user),
    )


@router.post("/logout", response_model=OKResponse, summary="Revoke refresh token")
async def logout(
    payload: LogoutRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: CurrentUser,
):
    await auth_service.logout(db, raw_refresh=payload.refresh_token)
    return OKResponse(message="Signed out")


@router.post(
    "/forgot-password",
    response_model=OKResponse,
    summary="Request password reset email",
)
async def forgot_password(
    payload: ForgotPasswordRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await auth_service.request_password_reset(db, str(payload.email))
    return OKResponse(
        message="If an account exists for that email, a reset link has been sent."
    )


@router.post("/reset-password", response_model=OKResponse, summary="Set new password")
async def reset_password(
    payload: ResetPasswordRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await auth_service.reset_password(
        db, raw_token=payload.token, new_password=payload.password
    )
    return OKResponse(message="Password updated. Please sign in.")


@router.get("/me", response_model=UserRead, summary="Current auth user")
async def auth_me(current_user: CurrentUser):
    return UserRead.model_validate(current_user)
