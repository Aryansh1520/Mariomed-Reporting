import re

_MOBILE_PATTERN = re.compile(r"\d{10}")
_EMAIL_PATTERN = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def normalize_mobile(value: str) -> str:
    """Strips spaces and a leading +91. Raises ValueError unless exactly 10 digits remain."""
    digits = re.sub(r"\s", "", value)
    if digits.startswith("+91"):
        digits = digits[3:]
    if not _MOBILE_PATTERN.fullmatch(digits):
        raise ValueError("Enter a 10-digit mobile number.")
    return digits


def normalize_pin(value: str) -> str:
    """An empty PIN is allowed. Otherwise it must be exactly six digits."""
    digits = value.strip()
    if digits and (not digits.isdigit() or len(digits) != 6):
        raise ValueError("Enter a 6-digit PIN code.")
    return digits


def normalize_email(value: str) -> str:
    email = value.strip().lower()
    if not _EMAIL_PATTERN.fullmatch(email):
        raise ValueError("Enter a valid email address.")
    return email


def normalize_full_name(value: str) -> str:
    """Trims the name. Every user needs one, so a blank or spaces-only name is refused."""
    name = value.strip()
    if not name:
        raise ValueError("Enter the full name.")
    return name
