from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth import service
from app.modules.auth.dependencies import get_principal
from app.modules.auth.schemas import (
    CurrentUserRead,
    LoginRequest,
    LoginResponse,
    PasswordResetConfirm,
    PasswordResetRequest,
)
from app.modules.rbac.principal import Principal

router = APIRouter()


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    return service.login(db, body)


@router.post("/logout", response_model=None)
def logout(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.logout(db, principal)


@router.get("/me", response_model=CurrentUserRead)
def me(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> CurrentUserRead:
    return service.current_user(db, principal)


@router.post("/password-reset/request", response_model=None)
def request_password_reset(
    body: PasswordResetRequest,
    db: Session = Depends(get_db),
) -> None:
    service.request_password_reset(db, body.identifier)


@router.post("/password-reset/confirm", response_model=None)
def confirm_password_reset(
    body: PasswordResetConfirm,
    db: Session = Depends(get_db),
) -> None:
    service.confirm_password_reset(db, body.identifier, body.code, body.new_password)
