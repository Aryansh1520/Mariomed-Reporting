from collections.abc import Callable

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.exceptions import Unauthorized
from app.db.session import get_db
from app.modules.auth import service
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm
from app.modules.rbac.principal import Principal

_bearer = HTTPBearer(auto_error=False)


def get_principal(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> Principal:
    if credentials is None:
        raise Unauthorized("Sign in to continue.")
    return service.authenticate_token(db, credentials.credentials)


def require_permission(code: Perm) -> Callable[[Principal], Principal]:
    """Route dependency. Returns the caller only when their role grants `code`."""

    def check(principal: Principal = Depends(get_principal)) -> Principal:
        rbac_service.require_scope(principal, code)
        return principal

    return check
