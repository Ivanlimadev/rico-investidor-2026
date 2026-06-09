from __future__ import annotations

import logging

from app.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    def send_password_reset(self, *, to_email: str, reset_url: str) -> None:
        subject = "Rico Investidor — reset your password"
        body = (
            f"Use the link below to reset your password (valid for 1 hour):\n\n"
            f"{reset_url}\n\n"
            "If you did not request this, you can ignore this email."
        )

        if settings.app_env.strip().lower() != "production":
            logger.info("Password reset email to %s: %s", to_email, reset_url)
            return

        api_key = settings.resend_api_key.strip()
        if not api_key:
            logger.warning("RESEND_API_KEY missing; password reset link: %s", reset_url)
            return

        try:
            import httpx

            httpx.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "from": settings.resend_from_email,
                    "to": [to_email],
                    "subject": subject,
                    "text": body,
                },
                timeout=15.0,
            ).raise_for_status()
        except Exception as exc:
            logger.error("Failed to send password reset email: %s", exc)
