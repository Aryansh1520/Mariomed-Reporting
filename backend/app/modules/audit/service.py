from sqlalchemy.orm import Session

from app.modules.audit.models import AuditEvent


def record(
    db: Session,
    actor_user_id: int | None,
    action: str,
    entity: str,
    entity_id: int | None,
) -> None:
    """Adds the event to the current transaction. It is saved when the caller commits."""
    db.add(
        AuditEvent(
            actor_user_id=actor_user_id,
            action=action,
            entity=entity,
            entity_id=entity_id,
        )
    )
