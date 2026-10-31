"""Wraps every JSON response in a uniform envelope:

    {"success": bool, "message": str, "data": any}

Pure ASGI middleware, so it sees every response, including errors that FastAPI
turns into responses (404, 422, HTTPException) and unhandled exceptions (500).
"""

import json
import logging
from http import HTTPStatus

from starlette.types import ASGIApp, Message, Receive, Scope, Send

logger = logging.getLogger(__name__)

# Paths served as-is. Docs and the OpenAPI schema must stay in their native formats.
EXCLUDED_PATHS = frozenset({"/docs", "/docs/oauth2-redirect", "/redoc", "/openapi.json", "/health"})

# These status codes must not carry a body, so they are never wrapped.
PASSTHROUGH_STATUS = frozenset({204, 304})


def _phrase(status: int) -> str:
    try:
        return HTTPStatus(status).phrase
    except ValueError:
        return "Request failed"


def _error_message_and_data(status: int, detail: object) -> tuple[str, object]:
    if status >= 500:
        # Never leak internal error details to clients; they are in the server log.
        return "Internal server error", None
    if isinstance(detail, str):
        return detail, None
    if status == 422:
        return "Validation error", detail
    return _phrase(status), detail


def _envelope_bytes(status: int, raw: bytes, is_json: bool) -> bytes | None:
    """Return the wrapped body, or None if the response should be sent unchanged."""
    if status in PASSTHROUGH_STATUS or not is_json:
        return None

    try:
        parsed = json.loads(raw) if raw else None
    except ValueError:
        return None

    if status < 400:
        envelope = {"success": True, "message": "Success", "data": parsed}
    else:
        detail = parsed.get("detail") if isinstance(parsed, dict) else parsed
        message, data = _error_message_and_data(status, detail)
        envelope = {"success": False, "message": message, "data": data}

    return json.dumps(envelope, ensure_ascii=False, default=str).encode("utf-8")


def _with_body(headers: list[tuple[bytes, bytes]], body: bytes) -> list[tuple[bytes, bytes]]:
    kept = [(k, v) for k, v in headers if k.lower() != b"content-length"]
    kept.append((b"content-length", str(len(body)).encode()))
    return kept


class ResponseEnvelopeMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["path"] in EXCLUDED_PATHS:
            await self.app(scope, receive, send)
            return

        start: Message | None = None
        chunks: list[bytes] = []
        finished = False

        async def capture(message: Message) -> None:
            nonlocal start, finished
            if message["type"] == "http.response.start":
                start = message
            elif message["type"] == "http.response.body":
                chunks.append(message.get("body", b""))
                if not message.get("more_body", False):
                    finished = True
                    await _send_buffered(start, b"".join(chunks), send)

        try:
            await self.app(scope, receive, capture)
        except Exception:
            logger.exception("Unhandled error on %s %s", scope["method"], scope["path"])
            if finished:
                raise
            # Nothing has reached the client yet, so a clean 500 envelope can still be sent.
            await _send_buffered(
                {"type": "http.response.start", "status": 500, "headers": [(b"content-type", b"application/json")]},
                b"",
                send,
                force_json=True,
            )


async def _send_buffered(start: Message, raw: bytes, send: Send, force_json: bool = False) -> None:
    status = start["status"]
    headers = list(start.get("headers", []))
    content_type = next((v for k, v in headers if k.lower() == b"content-type"), b"")
    is_json = force_json or content_type.lower().startswith(b"application/json")

    body = _envelope_bytes(status, raw, is_json)
    if body is None:
        await send({"type": "http.response.start", "status": status, "headers": headers})
        await send({"type": "http.response.body", "body": raw})
        return

    await send({"type": "http.response.start", "status": status, "headers": _with_body(headers, body)})
    await send({"type": "http.response.body", "body": body})
