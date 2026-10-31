from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.planning.models import DayPlanItem


def list_items(db: Session, user_id: int, date_from: date, date_to: date) -> list[DayPlanItem]:
    query = (
        select(DayPlanItem)
        .where(DayPlanItem.user_id == user_id, DayPlanItem.plan_date.between(date_from, date_to))
        .order_by(DayPlanItem.plan_date, DayPlanItem.id)
    )
    return list(db.scalars(query))


def list_all_items(db: Session, date_from: date, date_to: date) -> list[DayPlanItem]:
    query = select(DayPlanItem).where(DayPlanItem.plan_date.between(date_from, date_to))
    return list(db.scalars(query))


def items_on(db: Session, user_id: int, plan_date: date) -> list[DayPlanItem]:
    return list(db.scalars(select(DayPlanItem).where(DayPlanItem.user_id == user_id, DayPlanItem.plan_date == plan_date)))


def get_item(db: Session, item_id: int) -> DayPlanItem | None:
    return db.get(DayPlanItem, item_id)


def exists(db: Session, user_id: int, plan_date: date, contact_id: int) -> bool:
    return db.scalar(
        select(DayPlanItem.id).where(
            DayPlanItem.user_id == user_id,
            DayPlanItem.plan_date == plan_date,
            DayPlanItem.contact_id == contact_id,
        )
    ) is not None


def add(db: Session, item: DayPlanItem) -> DayPlanItem:
    db.add(item)
    db.flush()
    return item


def delete(db: Session, item: DayPlanItem) -> None:
    db.delete(item)
