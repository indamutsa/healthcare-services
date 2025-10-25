"""
Prediction service orchestrating model inference and caching.
"""

import hashlib
import json
import logging
from datetime import datetime
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd
import redis
from redis.exceptions import RedisError

from config import ServiceSettings
from models.model_loader import ModelLoader
from schemas.request import PredictionInstance, PredictionRequest
from schemas.response import ModelMetadata, PredictionResult

_LOGGER = logging.getLogger(__name__)


class Predictor:
    """High-level predictor that handles caching and post-processing."""

    def __init__(self, loader: ModelLoader, settings: ServiceSettings):
        self._loader = loader
        self._settings = settings
        self._redis = self._init_redis(settings)

    def predict(self, request: PredictionRequest) -> Tuple[List[PredictionResult], bool, ModelMetadata]:
        """
        Execute predictions for the provided request.

        Returns:
            Tuple of (results, cached_flag, model_metadata)
        """
        bundle = self._loader.get_model()
        model = bundle.model
        threshold = self._settings.prediction_threshold
        use_cache = request.use_cache and self._redis is not None

        payload_df = self._to_dataframe(request.records)
        cache_keys = tuple(self._build_cache_key(record.features) for record in request.records)

        cached_payload: Dict[int, PredictionResult] = {}
        cacheable_indices: Tuple[int, ...]

        if use_cache:
            cached_payload = self._read_from_cache(cache_keys, bundle.version)
            cacheable_indices = tuple(idx for idx in range(len(request.records)) if idx not in cached_payload)
        else:
            cacheable_indices = tuple(range(len(request.records)))

        predictions: Dict[int, PredictionResult] = dict(cached_payload)

        if cacheable_indices:
            fresh_df = payload_df.iloc[list(cacheable_indices)]
            try:
                raw_output = model.predict(fresh_df)
            except AttributeError:
                raw_output = model.predict_proba(fresh_df)  # type: ignore[attr-defined]

            probabilities = self._coerce_probabilities(raw_output)
            for position, probability in zip(cacheable_indices, probabilities):
                record = request.records[position]
                result = PredictionResult(
                    patient_id=record.patient_id,
                    probability=float(probability),
                    predicted_class=int(probability >= threshold),
                    threshold=threshold,
                    metadata=record.metadata,
                )
                predictions[position] = result

            if use_cache:
                self._write_to_cache(
                    {cache_keys[pos]: predictions[pos] for pos in cacheable_indices},
                    bundle.version,
                )

        ordered_results = [predictions[idx] for idx in range(len(request.records))]
        metadata = ModelMetadata(
            name=self._settings.model_name,
            version=bundle.version,
            stage=self._settings.model_stage,
            run_id=bundle.run_id,
            loaded_at=datetime.fromtimestamp(bundle.loaded_at),
        )

        return ordered_results, len(cached_payload) == len(request.records), metadata

    def cache_status(self) -> Dict[str, bool]:
        """Return runtime cache diagnostics."""
        enabled = self._redis is not None
        if not enabled:
            return {"enabled": False, "reachable": False}

        try:
            self._redis.ping()
            return {"enabled": True, "reachable": True}
        except RedisError:
            return {"enabled": True, "reachable": False}

    def current_model_metadata(self) -> ModelMetadata:
        """Expose metadata for the active model."""
        bundle = self._loader.get_model()
        return ModelMetadata(
            name=self._settings.model_name,
            version=bundle.version,
            stage=self._settings.model_stage,
            run_id=bundle.run_id,
            loaded_at=datetime.fromtimestamp(bundle.loaded_at),
        )

    def _init_redis(self, settings: ServiceSettings):
        try:
            pool = redis.ConnectionPool(
                host=settings.redis_host,
                port=settings.redis_port,
                db=settings.redis_db,
                username=settings.redis_username,
                password=settings.redis_password,
                decode_responses=False,
                ssl=settings.redis_tls,
                socket_timeout=2.0,
                socket_connect_timeout=2.0,
            )
            return redis.Redis(connection_pool=pool)
        except RedisError as exc:
            _LOGGER.warning("Failed to establish Redis connection", exc_info=exc)
            return None

    @staticmethod
    def _to_dataframe(records: Iterable[PredictionInstance]) -> pd.DataFrame:
        """Convert batch of instances to DataFrame using vectorized construction."""
        payload = [record.features for record in records]
        return pd.DataFrame.from_records(payload)

    @staticmethod
    def _build_cache_key(features: Dict[str, float]) -> str:
        """Create a deterministic cache key from the feature payload."""
        serialized = json.dumps(features, sort_keys=True, separators=(",", ":"))
        return hashlib.sha1(serialized.encode("utf-8")).hexdigest()

    def _read_from_cache(
        self, keys: Tuple[str, ...], version: str
    ) -> Dict[int, PredictionResult]:
        if not self._redis:
            return {}

        try:
            cached_entries = self._redis.mget(keys)
        except RedisError as exc:
            _LOGGER.warning("Prediction cache read failed", exc_info=exc)
            return {}

        cached_results: Dict[int, PredictionResult] = {}
        for idx, item in enumerate(cached_entries):
            if item is None:
                continue
            payload = json.loads(item)
            if payload.get("version") != version:
                continue
            cached_results[idx] = PredictionResult(**payload["result"])
        return cached_results

    def _write_to_cache(self, values: Dict[str, PredictionResult], version: str) -> None:
        if not self._redis or not values:
            return

        context = {
            key: json.dumps({"version": version, "result": result.dict()})
            for key, result in values.items()
        }

        try:
            with self._redis.pipeline(transaction=False) as pipe:
                for key, payload in context.items():
                    pipe.setex(key, self._settings.redis_ttl_seconds, payload)
                pipe.execute()
        except RedisError as exc:
            _LOGGER.warning("Prediction cache write failed", exc_info=exc)

    @staticmethod
    def _coerce_probabilities(raw_output) -> np.ndarray:
        """Normalize model output into a probability vector."""
        if isinstance(raw_output, tuple):
            raw_output = raw_output[0]

        if hasattr(raw_output, "shape") and len(raw_output.shape) == 2 and raw_output.shape[1] == 2:
            return raw_output[:, 1]

        array = np.asarray(raw_output).flatten()
        return array
