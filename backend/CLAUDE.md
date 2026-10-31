# Backend rules (FastAPI)

Shared rules in `../CLAUDE.md` also apply. The backend runs in Docker: `docker compose up -d` from the project root.

## Where code goes
- `app/main.py`: app creation, middleware and router registration only.
- `app/core/`: cross-cutting code only: `config.py` (settings), `security.py` (hashing, tokens), `exceptions.py` (domain errors), `response_envelope.py`, `openapi.py`, `audit.py` (shared column mixin), shared dependencies. Nothing domain-specific.
- `app/db/`: `session.py` (engine and `get_db`), `base.py` (declarative `Base`), `models.py` (imports every ORM model so Alembic sees them), `seed.py` (demo data).
- `app/api/router.py`: mounts each module's router under `/api/v1`. Nothing else.
- `app/modules/<domain>/`: all domain code, one folder per domain:
  - `router.py`: HTTP only. Parse input, call one service function, return its result. No queries, no business rules, no try/except around service calls.
  - `service.py`: business rules, permission checks, orchestration, transactions. Calls repository functions. Raises domain exceptions.
  - `repository.py`: SQLAlchemy queries only. Takes a `Session` and explicit arguments. No business rules.
  - `models.py`: ORM classes.
  - `schemas.py`: Pydantic request and response models.
- `migrations/`: Alembic revisions only. Never call `Base.metadata.create_all` in app code.

A module may import from `app/core` and `app/db`. It may import another module only through that module's `service.py`, never its `repository.py` or `models.py`, except for foreign-key references.

## Framework
- FastAPI with a synchronous SQLAlchemy 2 session. Route functions are plain `def`, not `async`, because the database layer is synchronous.
- Pydantic v2 for every request and response shape.

## Naming
- Modules, files and functions: `snake_case`. Classes: `PascalCase`.
- Tables: plural `snake_case` (`contacts`). ORM classes: singular (`Contact`).
- Service functions are verbs describing the business action: `create_contact`, `update_contact`, `list_contacts`, `schedule_visit`, `complete_task`.
- Repository functions describe the data access: `get_by_id`, `list_page`, `add`, `update_fields`, `count_all`. Do not repeat the module name inside repository function names.
- Router functions: named after the endpoint action, one function per route, no logic in the body.
- Schemas: `ContactCreate`, `ContactUpdate`, `ContactRead`, `ContactListQuery`.
- Booleans start with `is_`, `has_` or `can_`.

## Function rules
- Every function has type hints on arguments and return values. Use `X | None`, not `Optional[X]`.
- Keep functions short and single-purpose. If a function needs a comment to say what it does, split it or rename it.
- No function takes more than about four arguments. Group them in a schema or a small dataclass.
- No mutable default arguments. No `dict` or `Any` as a function's public type when a schema exists.

## Data and security
- Record access is checked in the service layer through the caller's permission scope (`all`, `self`, `assigned`), using the rbac service's access filter. The caller comes from the authenticated principal, never from the request body.
- Validation lives in Pydantic schemas (format, length, enums) and in service functions (business rules such as duplicate mobile numbers and follow-up date rules). Do not duplicate a rule in both places.
- Use the master tables for products, visit statuses, task types, contact categories and similar configurable values. Do not hard-code those lists in code.
- Use `settings` from `app/core/config.py`. Do not call `os.getenv` in other files.
- Never log passwords, tokens or personal contact details. Use `logger = logging.getLogger(__name__)`. No `print`.
- Soft-delete business records with a status or `deleted_at`. Visit and activity history is append-only; do not update or delete it except through the audit path.

## Errors
- Raise domain exceptions from `app/core/exceptions.py`. Each carries an HTTP status and a message.
- The envelope middleware turns them into the response. Routes and services must not build error responses by hand.
- Never return a 200 with an error payload.

## Responses
- Routes return a Pydantic model or plain data. The envelope middleware adds `success`, `message` and `data`.
- Set `response_model` on every route so Swagger shows the real shape.
- Lists are paginated: accept `page` and `page_size` and return the total count. Never return an unbounded list.

## Reuse
- Shared pagination, filtering and timestamp fields go in `app/core/`. Do not copy them into each module.
- Before writing a query, check whether an existing repository function already covers it.
- Two modules need the same logic: move it to `app/core/` or into the owning module's service. Do not copy it.

## Database
- Schema changes go through an Alembic revision with a clear message. Never edit an applied revision. Generate revisions with `docker compose run --rm api alembic revision --autogenerate -m "message"`; the compose file mounts `migrations/`, so the file lands in the project.
- Every business table has `created_at`, `updated_at`, `created_by` and `updated_by` (the `AuditFieldsMixin`).
- Use foreign keys and constraints. Do not store structured business data as JSON when a table fits.
