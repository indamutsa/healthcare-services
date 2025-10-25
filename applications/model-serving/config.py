"""
Service configuration for the model serving API.
"""

from functools import lru_cache
from typing import Optional

from pydantic import BaseSettings, Field, PositiveInt, conint


class ServiceSettings(BaseSettings):
    """Runtime configuration loaded from environment variables."""

    service_name: str = Field("clinical-model-serving", description="Service identifier")
    environment: str = Field("development", description="Deployment environment name")
    log_level: str = Field("INFO", description="Root log level")

    # MLflow configuration
    mlflow_tracking_uri: str = Field(..., env="MLFLOW_TRACKING_URI")
    model_name: str = Field(..., env="MODEL_NAME")
    model_stage: str = Field("Production", env="MODEL_STAGE")
    model_refresh_interval_seconds: PositiveInt = Field(
        300, description="How frequently to poll MLflow for a new model version"
    )

    # Prediction configuration
    prediction_threshold: float = Field(
        0.5,
        ge=0.0,
        le=1.0,
        description="Decision threshold applied to predicted probabilities",
    )

    # Redis caching configuration
    redis_host: str = Field("redis", env="REDIS_HOST")
    redis_port: conint(gt=0, lt=65536) = Field(6379, env="REDIS_PORT")
    redis_db: int = Field(0, env="REDIS_DB")
    redis_tls: bool = Field(False, env="REDIS_TLS")
    redis_username: Optional[str] = Field(None, env="REDIS_USERNAME")
    redis_password: Optional[str] = Field(None, env="REDIS_PASSWORD")
    redis_ttl_seconds: PositiveInt = Field(
        600, description="How long to cache predictions in Redis"
    )

    # Security
    api_key: Optional[str] = Field(None, env="MODEL_API_KEY")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> ServiceSettings:
    """Return cached settings instance."""
    return ServiceSettings()
