"""Limits password guesses per account. Counts live in this process, so a multi-instance deployment needs a shared store."""

import logging
import threading
import time

from app.core.exceptions import TooManyAttempts

MAX_FAILURES = 5
WINDOW_SECONDS = 15 * 60
LOCK_SECONDS = 15 * 60
TOO_MANY = "Too many failed sign-in attempts. Wait a few minutes and try again."

logger = logging.getLogger("auth")
_lock = threading.Lock()
_failures: dict[str, list[float]] = {}
_locked_until: dict[str, float] = {}


def _key(identifier: str) -> str:
    return identifier.strip().lower()


def check(identifier: str) -> None:
    key = _key(identifier)
    now = time.monotonic()
    with _lock:
        until = _locked_until.get(key)
        if until is not None and now < until:
            raise TooManyAttempts(TOO_MANY)
        if until is not None:
            del _locked_until[key]


def record_failure(identifier: str) -> None:
    key = _key(identifier)
    now = time.monotonic()
    with _lock:
        recent = [moment for moment in _failures.get(key, []) if now - moment < WINDOW_SECONDS]
        recent.append(now)
        _failures[key] = recent
        if len(recent) >= MAX_FAILURES:
            _locked_until[key] = now + LOCK_SECONDS
            _failures.pop(key, None)
    # Only a masked identifier reaches the log, never the password.
    logger.warning("failed sign-in for account ending %s", key[-4:])


def record_success(identifier: str) -> None:
    key = _key(identifier)
    with _lock:
        _failures.pop(key, None)
        _locked_until.pop(key, None)
