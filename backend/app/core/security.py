import hashlib
import hmac
import secrets
from base64 import b64decode, b64encode

_SCRYPT_N = 2**14
_SCRYPT_R = 8
_SCRYPT_P = 1
_SALT_BYTES = 16
_KEY_BYTES = 32


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(_SALT_BYTES)
    digest = hashlib.scrypt(
        password.encode(), salt=salt, n=_SCRYPT_N, r=_SCRYPT_R, p=_SCRYPT_P, dklen=_KEY_BYTES
    )
    return "$".join(
        [
            "scrypt",
            str(_SCRYPT_N),
            str(_SCRYPT_R),
            str(_SCRYPT_P),
            _encode(salt),
            _encode(digest),
        ]
    )


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, n, r, p, salt, digest = stored_hash.split("$")
    except ValueError:
        return False
    if algorithm != "scrypt":
        return False
    expected = _decode(digest)
    candidate = hashlib.scrypt(
        password.encode(),
        salt=_decode(salt),
        n=int(n),
        r=int(r),
        p=int(p),
        dklen=len(expected),
    )
    return hmac.compare_digest(candidate, expected)


def new_token() -> str:
    return secrets.token_urlsafe(32)


def new_reset_code() -> str:
    return f"{secrets.randbelow(10**6):06d}"


def hash_token(token: str) -> str:
    """Only the hash is stored, so a leaked database does not leak live sessions or reset links."""
    return hashlib.sha256(token.encode()).hexdigest()


def _encode(value: bytes) -> str:
    return b64encode(value).decode()


def _decode(value: str) -> bytes:
    return b64decode(value)
