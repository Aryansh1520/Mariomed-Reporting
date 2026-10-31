"""The permission catalogue. Code defines what can be granted; roles are data.

Scopes decide which records a grant reaches:
- all: every record in the system.
- self: only the caller's own records (the owner is whoever created the record).
- assigned: only records explicitly assigned to the caller, whoever owns them.

Team and territory scopes are added with the Teams and Territories module.
"""

from collections.abc import Mapping
from dataclasses import dataclass
from enum import StrEnum


class PermissionScope(StrEnum):
    ALL = "all"
    SELF = "self"
    ASSIGNED = "assigned"


class Perm(StrEnum):
    USERS_READ = "users.read"
    USERS_MANAGE = "users.manage"
    TEAMS_READ = "teams.read"
    TEAMS_MANAGE = "teams.manage"
    TERRITORIES_READ = "territories.read"
    TERRITORIES_MANAGE = "territories.manage"
    PRODUCTS_READ = "products.read"
    PRODUCTS_MANAGE = "products.manage"
    CONTACTS_READ = "contacts.read"
    CONTACTS_MANAGE = "contacts.manage"
    CONTACTS_ASSIGN = "contacts.assign"
    CONTACTS_EXPORT = "contacts.export"
    PLANS_READ = "plans.read"
    PLANS_MANAGE = "plans.manage"
    VISITS_READ = "visits.read"
    VISITS_MANAGE = "visits.manage"
    VISITS_REVIEW = "visits.review"
    TASKS_READ = "tasks.read"
    TASKS_MANAGE = "tasks.manage"
    TASKS_ASSIGN = "tasks.assign"
    DAILY_REPORTS_READ = "daily_reports.read"
    DAILY_REPORTS_MANAGE = "daily_reports.manage"
    DAILY_REPORTS_REVIEW = "daily_reports.review"
    TARGETS_READ = "targets.read"
    TARGETS_MANAGE = "targets.manage"
    TARGETS_APPROVE = "targets.approve"
    ANALYTICS_READ = "analytics.read"
    NOTIFICATIONS_READ = "notifications.read"
    NOTIFICATIONS_MANAGE = "notifications.manage"
    DATA_IMPORT = "data.import"
    SETTINGS_MANAGE = "settings.manage"
    AUDIT_READ = "audit.read"
    ADMIN_DASHBOARD = "admin.dashboard"
    ROLES_MANAGE = "roles.manage"


@dataclass(frozen=True)
class PermissionDefinition:
    code: Perm
    description: str
    module: str
    # Whether the permission is granted at a scope. Create-type permissions are not scoped.
    scoped: bool
    # The permission this one needs in order to mean anything. Read is the base of its module.
    requires: Perm | None = None


PERMISSIONS: tuple[PermissionDefinition, ...] = (
    PermissionDefinition(Perm.USERS_READ, "View team members", "Team", True),
    PermissionDefinition(Perm.USERS_MANAGE, "Add, edit, activate or deactivate team members", "Team", True, Perm.USERS_READ),
    PermissionDefinition(Perm.TEAMS_READ, "View teams and their members", "Teams", True),
    PermissionDefinition(Perm.TEAMS_MANAGE, "Create, rename, archive teams and change membership", "Teams", True, Perm.TEAMS_READ),
    PermissionDefinition(Perm.TERRITORIES_READ, "View zones and subzones", "Territories", True),
    PermissionDefinition(Perm.TERRITORIES_MANAGE, "Create, edit, deactivate zones and subzones and assign users to them", "Territories", True, Perm.TERRITORIES_READ),
    PermissionDefinition(Perm.PRODUCTS_READ, "View the product catalogue", "Products", False),
    PermissionDefinition(Perm.PRODUCTS_MANAGE, "Add, edit and deactivate products", "Products", False, Perm.PRODUCTS_READ),
    PermissionDefinition(Perm.CONTACTS_READ, "View contacts and their interaction history", "Contacts", True),
    PermissionDefinition(Perm.CONTACTS_MANAGE, "Create and edit contacts", "Contacts", True, Perm.CONTACTS_READ),
    PermissionDefinition(Perm.CONTACTS_ASSIGN, "Assign and reassign contacts", "Contacts", True, Perm.CONTACTS_READ),
    PermissionDefinition(Perm.CONTACTS_EXPORT, "Export contact records", "Contacts", True, Perm.CONTACTS_READ),
    PermissionDefinition(Perm.PLANS_READ, "View daily and weekly plans", "Planning", True),
    PermissionDefinition(Perm.PLANS_MANAGE, "Create, assign and reschedule plans", "Planning", True, Perm.PLANS_READ),
    PermissionDefinition(Perm.VISITS_READ, "View visit reports", "Visits", True),
    PermissionDefinition(Perm.VISITS_MANAGE, "Record, edit and submit visit reports", "Visits", True, Perm.VISITS_READ),
    PermissionDefinition(Perm.VISITS_REVIEW, "Approve or reject submitted visit reports", "Visits", True, Perm.VISITS_READ),
    PermissionDefinition(Perm.TASKS_READ, "View tasks and follow-ups", "Tasks", True),
    PermissionDefinition(Perm.TASKS_MANAGE, "Create, update and close tasks", "Tasks", True, Perm.TASKS_READ),
    PermissionDefinition(Perm.TASKS_ASSIGN, "Assign and reassign tasks", "Tasks", True, Perm.TASKS_READ),
    PermissionDefinition(Perm.DAILY_REPORTS_READ, "View daily activity reports", "Daily reports", True),
    PermissionDefinition(Perm.DAILY_REPORTS_MANAGE, "Prepare and submit daily activity reports", "Daily reports", True, Perm.DAILY_REPORTS_READ),
    PermissionDefinition(Perm.DAILY_REPORTS_REVIEW, "Review, approve or reopen daily activity reports", "Daily reports", True, Perm.DAILY_REPORTS_READ),
    PermissionDefinition(Perm.TARGETS_READ, "View monthly targets and progress", "Targets", True),
    PermissionDefinition(Perm.TARGETS_MANAGE, "Create, allocate and update targets", "Targets", True, Perm.TARGETS_READ),
    PermissionDefinition(Perm.TARGETS_APPROVE, "Approve target revisions and manual adjustments", "Targets", True, Perm.TARGETS_READ),
    PermissionDefinition(Perm.ANALYTICS_READ, "View dashboards and reports", "Analytics", True),
    PermissionDefinition(Perm.NOTIFICATIONS_READ, "View notification delivery history", "Notifications", True),
    PermissionDefinition(Perm.NOTIFICATIONS_MANAGE, "Configure notification rules and escalations", "Notifications", False),
    PermissionDefinition(Perm.DATA_IMPORT, "Import users, products, contacts and targets from files", "Data", False),
    PermissionDefinition(Perm.SETTINGS_MANAGE, "Change system configuration and master values", "Settings", False),
    PermissionDefinition(Perm.AUDIT_READ, "View administrative and operational history", "Audit", False),
    PermissionDefinition(Perm.ADMIN_DASHBOARD, "View team-wide reports by employee, zone, product and category", "Admin", False),
    PermissionDefinition(Perm.ROLES_MANAGE, "View and change roles", "Roles", False),
)

_BY_CODE: Mapping[str, PermissionDefinition] = {d.code.value: d for d in PERMISSIONS}


def definition_of(code: str) -> PermissionDefinition:
    return _BY_CODE[code]


def with_dependencies(codes: Mapping[str, PermissionScope | None]) -> dict[str, PermissionScope | None]:
    """Adds every permission a granted one needs. An implied read takes the scope of the toggle that needs it.

    Giving it no scope would load it at the widest scope, so a narrow manage toggle would quietly widen its read.
    """
    result: dict[str, PermissionScope | None] = dict(codes)
    pending = list(codes)
    while pending:
        code = pending.pop()
        required = _BY_CODE[code].requires
        if required is None or required.value in result:
            continue
        needed_scope = result[code] if _BY_CODE[required.value].scoped else None
        result[required.value] = needed_scope or (PermissionScope.SELF if _BY_CODE[required.value].scoped else None)
        pending.append(required.value)
    return result


@dataclass(frozen=True)
class AdminRoleLock:
    """The one role the code knows. It always holds every permission at the widest scope."""

    code: str = "admin"
    name: str = "Administrator"


ADMIN_ROLE = AdminRoleLock()


def admin_grants() -> dict[str, PermissionScope]:
    return {definition.code.value: PermissionScope.ALL for definition in PERMISSIONS}


# Scopes from widest to narrowest. A holder of a wider scope may give a narrower one, never the reverse.
SCOPE_WIDTH: Mapping[PermissionScope, int] = {
    PermissionScope.ALL: 3,
    PermissionScope.SELF: 2,
    PermissionScope.ASSIGNED: 1,
}
