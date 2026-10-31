from fastapi import APIRouter

from app.modules.auth.router import router as auth_router
from app.modules.contacts.router import router as contacts_router
from app.modules.dashboard.router import router as dashboard_router
from app.modules.planning.router import router as planning_router
from app.modules.reports.router import router as reports_router
from app.modules.products.router import router as products_router
from app.modules.rbac.router import router as roles_router
from app.modules.territories.router import router as territories_router
from app.modules.visits.router import router as visits_router
from app.modules.users.router import router as users_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(users_router, prefix="/users", tags=["users"])
api_router.include_router(roles_router, prefix="/roles", tags=["roles"])
api_router.include_router(products_router, prefix="/products", tags=["products"])
api_router.include_router(territories_router, prefix="/territories", tags=["territories"])
api_router.include_router(contacts_router, prefix="/contacts", tags=["contacts"])
api_router.include_router(visits_router, prefix="/visits", tags=["visits"])
api_router.include_router(dashboard_router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(reports_router, prefix="/reports", tags=["reports"])
api_router.include_router(planning_router, prefix="/plans", tags=["plans"])
