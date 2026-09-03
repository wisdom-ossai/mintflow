"""
Resend transactional email client.
"""
from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


async def send_email(*, to: str, subject: str, html: str, text: str | None = None) -> bool:
    if not settings.RESEND_API_KEY:
        logger.warning("RESEND_API_KEY unset — email to %s not sent. Subject: %s", to, subject)
        if settings.is_development:
            logger.info("DEV email body:\n%s", text or html)
        return False

    payload: dict = {
        "from": settings.EMAIL_FROM,
        "to": [to],
        "subject": subject,
        "html": html,
    }
    if text:
        payload["text"] = text

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        if resp.status_code >= 400:
            logger.error("Resend failed %s: %s", resp.status_code, resp.text)
            return False
    return True


async def send_password_reset_email(*, to: str, raw_token: str) -> bool:
    deep = f"{settings.APP_DEEP_LINK_RESET}?token={raw_token}"
    web = f"{settings.APP_PUBLIC_URL}/reset-password?token={raw_token}"
    subject = "Reset your Flowra password"
    text = (
        "Reset your Flowra password using this link (expires soon):\n\n"
        f"{deep}\n\nOr open:\n{web}\n\n"
        "If you did not request this, you can ignore this email."
    )
    html = f"""
    <p>Reset your Flowra password using the button below. This link expires soon.</p>
    <p><a href="{deep}">Reset password in the app</a></p>
    <p>Or use this link: <a href="{web}">{web}</a></p>
    <p>If you did not request this, you can ignore this email.</p>
    """
    return await send_email(to=to, subject=subject, html=html, text=text)
