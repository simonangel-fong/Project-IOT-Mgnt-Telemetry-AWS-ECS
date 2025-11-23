from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal
from urllib.parse import quote_plus

from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


# ==============================
# PostgreSQL
# ==============================
class PostgresSettings(BaseModel):
    """PostgreSQL database configuration."""

    host: str = "postgres"
    port: int = 5432
    user: str = "app_user"
    db: str = "app_db"
    password: str = "postgres"

    @property
    def url(self) -> str:
        """
        SQLAlchemy async connection URL.

        Example:
            postgresql+asyncpg://user:password@host:5432/db
        """
        user = quote_plus(self.user)
        pwd = quote_plus(self.password)
        return f"postgresql+asyncpg://{user}:{pwd}@{self.host}:{self.port}/{self.db}"


# ==============================
# Redis
# ==============================
class RedisSettings(BaseModel):
    """Redis configuration."""

    host: str = "redis"
    port: int = 6379
    db: int = 0
    password: str | None = None

    @property
    def url(self) -> str:
        """
        Redis connection URL.

        Example:
            redis://:password@host:6379/0
            redis://host:6379/0
        """
        if self.password:
            pwd = quote_plus(self.password)
            return f"redis://:{pwd}@{self.host}:{self.port}/{self.db}"
        return f"redis://{self.host}:{self.port}/{self.db}"


# ==============================
# Application Settings
# ==============================
class Settings(BaseSettings):
    """Application settings."""

    # General
    app_name: str = "Iot management telemetry"
    cors: str = Field(
        default="http://localhost,http://localhost:8000,http://localhost:8080",
        alias="CORS",
        description="Comma-separated list of allowed CORS origins",
    )
    debug: bool = True
    env: Literal["dev", "staging", "prod"] = "dev"

    # Nested config
    postgres: PostgresSettings = PostgresSettings()
    redis: RedisSettings = RedisSettings()

    # Pydantic Settings config
    model_config = SettingsConfigDict(
        # project root .env
        env_file=str(Path(__file__).resolve().parent.parent.parent / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",               # ignore unknown env vars
        env_nested_delimiter="__",    # POSTGRES__HOST -> settings.postgres.host
    )

    # Convenience properties
    @property
    def postgres_url(self) -> str:
        """Postgres connection URL."""
        return self.postgres.url

    @property
    def redis_url(self) -> str:
        """Redis connection URL."""
        return self.redis.url

    @property
    def cors_list(self) -> list[str]:
        """Parsed list of CORS origins from the comma-separated string."""
        return [
            origin.strip()
            for origin in self.cors.split(",")
            if origin.strip()
        ]


# ==============================
# Settings
# ==============================
@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """
    Get a cached Settings instance.
    """
    return Settings()
