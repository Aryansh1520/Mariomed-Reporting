from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.holidays.models import Holiday


def list_between(db: Session, date_from: date, date_to: date) -> list[Holiday]:
    query = select(Holiday).where(Holiday.holiday_date.between(date_from, date_to))
    return list(db.scalars(query))
