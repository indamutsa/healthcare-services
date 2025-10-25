"""
Utilities for loading and refreshing MLflow models.
"""

import logging
import threading
import time
from dataclasses import dataclass
from typing import Any, Optional

import mlflow
from mlflow.tracking import MlflowClient

from config import ServiceSettings

_LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class LoadedModel:
    """Container with the loaded MLflow model and metadata."""

    model: Any
    version: str
    run_id: str
    loaded_at: float


class ModelLoader:
    """Thread-safe loader that keeps an MLflow model cached in memory."""

    def __init__(self, settings: ServiceSettings):
        self._settings = settings
        self._client = MlflowClient(tracking_uri=settings.mlflow_tracking_uri)
        self._lock = threading.RLock()
        self._cached: Optional[LoadedModel] = None
        self._last_checked: float = 0.0

    def get_model(self, force_refresh: bool = False) -> LoadedModel:
        """
        Return the currently served model, refreshing if stale.

        Args:
            force_refresh: Skip cache and reload from MLflow.
        """
        with self._lock:
            if force_refresh or self._requires_refresh():
                self._cached = self._load_latest_model()
            return self._cached  # type: ignore[return-value]

    def _requires_refresh(self) -> bool:
        """Determine whether the cached model should be refreshed."""
        if self._cached is None:
            return True

        now = time.time()
        if now - self._last_checked < self._settings.model_refresh_interval_seconds:
            return False

        self._last_checked = now
        latest = self._fetch_latest_version()
        if latest is None:
            return False

        if latest.version != self._cached.version:
            _LOGGER.info(
                "Detected newer model version",
                extra={"old_version": self._cached.version, "new_version": latest.version},
            )
            return True

        return False

    def _load_latest_model(self) -> LoadedModel:
        """Load the latest production model from MLflow."""
        latest = self._fetch_latest_version()
        if latest is None:
            raise RuntimeError(
                f"No model found in stage '{self._settings.model_stage}' for "
                f"{self._settings.model_name}"
            )

        model_uri = f"models:/{self._settings.model_name}/{self._settings.model_stage}"
        _LOGGER.info(
            "Loading model from MLflow",
            extra={"model_uri": model_uri, "version": latest.version, "run_id": latest.run_id},
        )
        model = mlflow.pyfunc.load_model(model_uri=model_uri)
        loaded = LoadedModel(
            model=model,
            version=latest.version,
            run_id=latest.run_id,
            loaded_at=time.time(),
        )
        self._last_checked = loaded.loaded_at
        return loaded

    def _fetch_latest_version(self):
        """Fetch metadata for the latest version in the configured stage."""
        candidates = self._client.get_latest_versions(
            self._settings.model_name, stages=[self._settings.model_stage]
        )
        if not candidates:
            return None
        # get_latest_versions already returns sorted by creation desc; take first
        return candidates[0]
