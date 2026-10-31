import json
import logging
from typing import Protocol
from urllib import request
from urllib.error import URLError

from app.core.config import settings

logger = logging.getLogger(__name__)

RESEND_SEND_URL = "https://api.resend.com/emails"


class MailError(Exception):
    """Raised when the provider refuses or cannot be reached. The message never includes the body."""


class Mailer(Protocol):
    def send(self, to_email: str, subject: str, text_body: str) -> None: ...


class DisabledMailer:
    def send(self, to_email: str, subject: str, text_body: str) -> None:
        logger.warning("Email not sent: MAIL_PROVIDER is disabled.")


class ResendMailer:
    """Sends through Resend. The sender domain must be verified in Resend, or every send is refused."""

    def __init__(self, api_key: str, from_email: str, from_name: str) -> None:
        self._api_key = api_key
        self._from_email = from_email
        self._from_name = from_name

    def send(self, to_email: str, subject: str, text_body: str) -> None:
        payload = {
            "from": f"{self._from_name} <{self._from_email}>",
            "to": [to_email],
            "subject": subject,
            "text": text_body,
        }
        # Resend sits behind Cloudflare, which rejects urllib's default User-Agent.
        req = request.Request(
            RESEND_SEND_URL,
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
                "User-Agent": "mariomed-api/1.0",
            },
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=10):
                return
        except URLError as exc:
            raise MailError(f"Resend request failed: {exc.reason}") from None


def get_mailer() -> Mailer:
    if settings.mail_provider == "resend":
        return ResendMailer(settings.resend_api_key, settings.mail_from_email, settings.mail_from_name)
    return DisabledMailer()
