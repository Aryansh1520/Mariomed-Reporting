from datetime import date
from typing import TypeVar

from sqlalchemy import delete as sql_delete
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.visits.models import Visit, VisitDay, VisitParticipation, visit_products

T = TypeVar("T", VisitDay, Visit, VisitParticipation)


def has_visits(db: Session, day_id: int) -> bool:
    return db.scalar(select(func.count()).select_from(Visit).where(Visit.day_id == day_id)) > 0


def visited_pairs(db: Session, user_id: int, date_from: date, date_to: date) -> set[tuple[date, int]]:
    rows = db.execute(
        select(Visit.visit_date, Visit.contact_id).where(
            Visit.user_id == user_id,
            Visit.visit_date.between(date_from, date_to),
            Visit.status != "rejected",
        )
    )
    return {(visit_date, contact_id) for visit_date, contact_id in rows}


def delete_day(db: Session, day: VisitDay) -> None:
    db.delete(day)


def get_day(db: Session, user_id: int, visit_date: date) -> VisitDay | None:
    return db.scalar(select(VisitDay).where(VisitDay.user_id == user_id, VisitDay.visit_date == visit_date))


def day_statuses(db: Session, day_ids: set[int]) -> dict[int, str]:
    rows = db.execute(select(VisitDay.id, VisitDay.status).where(VisitDay.id.in_(day_ids)))
    return {day_id: status for day_id, status in rows}


def list_days(db: Session, owner_id: int | None, date_from: date, date_to: date) -> list[VisitDay]:
    query = select(VisitDay).where(VisitDay.visit_date.between(date_from, date_to))
    if owner_id is not None:
        query = query.where(VisitDay.user_id == owner_id)
    return list(db.scalars(query.order_by(VisitDay.visit_date, VisitDay.id)))


def get_visit(db: Session, visit_id: int) -> Visit | None:
    return db.get(Visit, visit_id)


def list_visits(db: Session, owner_id: int | None, date_from: date, date_to: date) -> list[Visit]:
    query = select(Visit).where(Visit.visit_date.between(date_from, date_to), Visit.status != "rejected")
    if owner_id is not None:
        query = query.where(Visit.user_id == owner_id)
    return list(db.scalars(query.order_by(Visit.visit_date, Visit.visit_time, Visit.id)))


def visits_of_day(db: Session, day_id: int) -> list[Visit]:
    return list(db.scalars(select(Visit).where(Visit.day_id == day_id).order_by(Visit.visit_time, Visit.id)))


def products_of_visits(db: Session, visit_ids: set[int]) -> dict[int, list[int]]:
    rows = db.execute(
        select(visit_products.c.visit_id, visit_products.c.product_id).where(visit_products.c.visit_id.in_(visit_ids))
    )
    grouped: dict[int, list[int]] = {}
    for visit_id, product_id in rows:
        grouped.setdefault(visit_id, []).append(product_id)
    return grouped


def set_products(db: Session, visit_id: int, product_ids: list[int]) -> None:
    db.execute(sql_delete(visit_products).where(visit_products.c.visit_id == visit_id))
    db.execute(visit_products.insert(), [{"visit_id": visit_id, "product_id": pid} for pid in product_ids])


def participations_by_visit(db: Session, visit_ids: set[int]) -> dict[int, VisitParticipation]:
    rows = db.scalars(select(VisitParticipation).where(VisitParticipation.visit_id.in_(visit_ids)))
    return {participation.visit_id: participation for participation in rows}


def get_participation(db: Session, visit_id: int) -> VisitParticipation | None:
    return db.scalar(select(VisitParticipation).where(VisitParticipation.visit_id == visit_id))


def participations_for_user(db: Session, user_id: int, since: date) -> list[tuple[VisitParticipation, Visit]]:
    query = (
        select(VisitParticipation, Visit)
        .join(Visit, Visit.id == VisitParticipation.visit_id)
        .where(VisitParticipation.user_id == user_id, Visit.visit_date >= since)
        .order_by(Visit.visit_date, Visit.visit_time)
    )
    return [(participation, visit) for participation, visit in db.execute(query)]


def pending_participations_on(db: Session, user_id: int, visit_date: date) -> list[VisitParticipation]:
    query = (
        select(VisitParticipation)
        .join(Visit, Visit.id == VisitParticipation.visit_id)
        .where(
            VisitParticipation.user_id == user_id,
            VisitParticipation.status == "pending",
            Visit.visit_date == visit_date,
        )
    )
    return list(db.scalars(query))


def pending_participations_before(db: Session, cutoff: date) -> list[tuple[VisitParticipation, Visit]]:
    query = (
        select(VisitParticipation, Visit)
        .join(Visit, Visit.id == VisitParticipation.visit_id)
        .where(VisitParticipation.status == "pending", Visit.visit_date < cutoff)
    )
    return [(participation, visit) for participation, visit in db.execute(query)]


def add(db: Session, obj: T) -> T:
    db.add(obj)
    db.flush()
    return obj


def delete_visit(db: Session, visit: Visit) -> None:
    db.delete(visit)
