from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.dashboard import service
from app.modules.dashboard.schemas import DashboardRead
from app.modules.rbac.principal import Principal

router = APIRouter()


@router.get("", response_model=DashboardRead)
def get_dashboard(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> DashboardRead:
    return service.get_dashboard(db, principal)
