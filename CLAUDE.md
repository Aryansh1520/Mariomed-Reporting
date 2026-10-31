# Field Sales Management: shared rules

Read the CLAUDE.md in the folder you are editing as well (`backend/CLAUDE.md` or `mobile/CLAUDE.md`). Those rules win for their folder.

## Layout
- `mobile/`: Flutter app (Android, iOS, Linux desktop for local runs, web). GetX for state, routing and DI.
- `backend/`: FastAPI, SQLAlchemy 2, Alembic, Postgres. Runs in Docker.
- `docker-compose.yml`: Postgres and the API. Host ports are fixed: API 8200, Postgres 5452. Do not use 8000, 8100, 5432 or 5442 on the host (Project Y uses 8100 and 5442).
- Single company, single tenant. There is no organisation table and no per-tenant data split.

## Contract between the two
- Every JSON response has the envelope `{success: bool, message: string, data: any}`. The backend adds it through middleware, so routes return plain data. The mobile app unwraps it in the service layer only.
- Field names are `snake_case` in JSON. Dart models map them to `camelCase` in `fromJson`.
- Route paths are under `/api/v1`. The backend owns the route list; the mobile app keeps its endpoint strings in one place (its service layer).

## Working rules
- Do not add a dependency without asking first.
- No tests are written in this project. Do not create test files or test dependencies.
- Do not commit `.env` or any secret. `.env.example` is the template.
- Make one change at a time and keep diffs small. Do not rename or move existing files unless the task asks for it.
- Before creating a helper, search the existing code for one that already does the job.
- Do not leave TODOs, commented-out code or debug prints in finished code.
- Comments explain why, not what. Most code needs none.
- Data isolation is not a tenancy concern here, but record access is: every record is reached only through the caller's permission scope, enforced on the backend, never only in the UI.

## RBAC rules (apply to backend and mobile)

Roles and permissions
- Roles are data. The only hardcoded role is the admin: every permission at scope `all`, always, and it cannot be edited, switched off or deleted.
- Every other role is built by the admin: a name plus a set of permission toggles. A role starts empty; nothing is granted by default.
- Each permission is a toggle. Turning a toggle on for a permission that has a scope asks for the scope: `all`, `self` or `assigned`. Create-type permissions have no scope.
- Permissions depend on each other. Update, status, assign and delete each need read on the same module, so switching read off switches the others off, and switching one on switches read on.
- The permission catalogue is code. New features add permissions there; roles pick them up without code changes.

Scopes
- `all`: every record.
- `self`: only the user's own records. The owner is set when the record is created by that user, and never changes except by reassignment from someone allowed to reassign. Nobody else sees it.
- `assigned`: only records explicitly assigned to the user, whoever owns them. A field representative sees only assigned contacts and tasks.
- Scopes will widen later, as the business needs them: organisation-wide, zone, subzone, team and "me". Each new scope is a deliberate change to the scope model, made with the module that needs it, never by adding a value ad hoc.
- Feature code checks permissions only. No code checks a role name, except the admin lock. Who can do something is decided by the permissions the admin has granted, so a new role needs no code change.

Assignment
- Assignment grants access to a record. An assignee gets the same actions their role allows on that record's scope, nothing more.
- Assignment is bulk: pick many records and one or more users, then assign or unassign. Anyone holding the assign permission can do it within their own scope.
- Reassigning or unassigning removes access at once. Records assigned to a deactivated user return to their owner.

Safety
- No escalation: a user can only give a role permissions they hold themselves, at the same or a wider scope.
- No self-lockout: the admin cannot deactivate their own account.
- A role with users attached cannot be deleted; the admin must move those users first.
- Deactivated users lose access immediately, including on their open sessions.
- Every change to roles, toggles, assignments and user access is recorded with who made it and when.

Enforcement
- The backend is the authority. The app hides what a user cannot do, but every endpoint re-checks.
- Checks read the role's current toggles on each request, so a change applies without a new sign-in.
- Features declare the permission they need. Code never names a role, except the admin lock.
- Demo or seed roles go through the same role service the admin UI uses.

## Visual rules (mobile)
- Follow the `anti-ai-slop` skill in `.claude/skills/anti-ai-slop/`.
- The palette is blue. Semantic colours keep their meaning: go (green), alert (red), warning (amber), info. The brand accent is blue; no yellow or coral brand colours.
