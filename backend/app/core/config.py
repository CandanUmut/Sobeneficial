# app/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal

class Settings(BaseSettings):
    APP_NAME: str = "BenefiSocial"
    APP_ENV: str = "dev"
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8000
    API_PREFIX: str = "/api"
    LOG_LEVEL: str = "info"
    REQUEST_TIMEOUT: int = 15

    DATABASE_URL: str

    SUPABASE_JWKS_URL: str
    SUPABASE_AUDIENCE: str = "authenticated"

    CORS_ORIGINS: str = "http://localhost:3000"
    DEV_ALLOW_UNVERIFIED: bool = True
    # 🔽 ekledik
    DB_SSL_MODE: Literal["strict", "os", "relax"] = "strict"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

settings = Settings()
