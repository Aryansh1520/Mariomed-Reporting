"""Import every ORM model here so Alembic autogenerate sees them."""

from app.modules.audit.models import AuditEvent  # noqa: F401
from app.modules.auth.models import AuthSession, PasswordResetToken  # noqa: F401
from app.modules.contacts.models import Contact, ContactCategory  # noqa: F401
from app.modules.holidays.models import Holiday  # noqa: F401
from app.modules.planning.models import DayPlanItem  # noqa: F401
from app.modules.products.models import Product  # noqa: F401
from app.modules.rbac.models import Permission, Role, RolePermission  # noqa: F401
from app.modules.territories.models import MapRegion, Territory, UserTerritory  # noqa: F401
from app.modules.users.models import User  # noqa: F401
from app.modules.visits.models import Visit, VisitDay, VisitParticipation  # noqa: F401
