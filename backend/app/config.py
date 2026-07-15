from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://ff_user:ff_password@db:5432/family_finance"
    SECRET_KEY: str = "change-me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "/app/uploads"
    BACKUP_DIR: str = "/app/backups"

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
