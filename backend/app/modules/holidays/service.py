from datetime import date

from sqlalchemy.orm import Session

from app.modules.holidays import repository


def holiday_dates(db: Session, date_from: date, date_to: date) -> set[date]:
    return {holiday.holiday_date for holiday in repository.list_between(db, date_from, date_to)}


def holiday_name_on(db: Session, day: date) -> str | None:
    return next((holiday.name for holiday in repository.list_between(db, day, day)), None)
