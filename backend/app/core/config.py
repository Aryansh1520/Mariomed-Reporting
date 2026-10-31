from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Field Sales API"
    environment: str = "development"
    database_url: str = "postgresql+psycopg://fs:fs_dev_password@localhost:5452/field_sales"

    # Sessions are opaque tokens checked on every request, so deactivating a user takes effect at once.
    session_hours: int = 12

    # Password for the demo accounts that `python -m app.db.seed` creates. Development only.
    seed_password: str = "demo1234"

    # "resend" sends real email. "disabled" skips sending, so no reset link ever reaches a log.
    mail_provider: str = "disabled"
    resend_api_key: str = ""
    mail_from_email: str = ""
    mail_from_name: str = "Field Sales"

    # Browsers may call the API only from these origins. Dev accepts any localhost port,
    # because the Flutter web server picks its own. Production sets the real domain.
    cors_origin_regex: str = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    # Visit days are judged in the business's calendar, not the server's.
    business_timezone: str = "Asia/Kolkata"
    # A rep may report a day until this many days after it, after which the day is locked as missed.
    reporting_grace_days: int = 4

    password_reset_minutes: int = 30


settings = Settings()
