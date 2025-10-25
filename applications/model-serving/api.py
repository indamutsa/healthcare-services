"""
FastAPI application exposing the clinical model serving endpoints.
"""

import logging
import time
import uuid
from typing import Any, Dict

from fastapi import Depends, FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import get_settings
from middleware.auth import APIKeyAuthenticator
from middleware.logging import configure_logging, set_request_context
from models.model_loader import ModelLoader
from predictor import Predictor
from schemas.request import PredictionRequest
from schemas.response import PredictionResponse

settings = get_settings()
configure_logging(settings.log_level)

app = FastAPI(
    title="Clinical Model Serving API",
    description="Real-time adverse event risk scoring backed by MLflow models.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger = logging.getLogger("model-serving")

model_loader = ModelLoader(settings)
predictor = Predictor(model_loader, settings)
auth_dependency = APIKeyAuthenticator(settings.api_key)


@app.middleware("http")
async def inject_trace_context(request: Request, call_next):
    trace_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    set_request_context(trace_id)
    start_time = time.perf_counter()
    response = await call_next(request)
    duration_ms = (time.perf_counter() - start_time) * 1000
    logger.info(
        "request completed",
        extra={
            "trace_id": trace_id,
            "span_id": "-",
            "path": request.url.path,
            "method": request.method,
            "status": response.status_code,
            "duration_ms": round(duration_ms, 2),
        },
    )
    return response


@app.on_event("startup")
def warm_model() -> None:
    """Load the model into memory on startup for faster first predictions."""
    bundle = model_loader.get_model()
    logger.info(
        "model cached",
        extra={
            "trace_id": "-",
            "span_id": "-",
            "model_name": settings.model_name,
            "version": bundle.version,
            "stage": settings.model_stage,
        },
    )


@app.get("/health")
def health_check():
    """Lightweight health probe for container orchestrators."""
    cache = predictor.cache_status()
    bundle = model_loader.get_model()
    payload = {
        "status": "ok",
        "model": {
            "name": settings.model_name,
            "version": bundle.version,
            "stage": settings.model_stage,
            "run_id": bundle.run_id,
        },
        "cache": cache,
    }
    status_code = (
        status.HTTP_200_OK if cache["enabled"] is False or cache["reachable"] else status.HTTP_503_SERVICE_UNAVAILABLE
    )
    return JSONResponse(content=payload, status_code=status_code)


@app.get("/ready")
def readiness_check() -> Dict[str, Any]:
    """Readiness probe ensuring the model is available."""
    bundle = model_loader.get_model()
    cache = predictor.cache_status()
    return {
        "status": "ready",
        "model_version": bundle.version,
        "cache": cache,
    }


@app.post("/v1/predict", response_model=PredictionResponse)
async def predict(
    payload: PredictionRequest, _: None = Depends(auth_dependency)
) -> PredictionResponse:
    """Score one or more records and return probabilities."""
    results, served_from_cache, metadata = predictor.predict(payload)
    return PredictionResponse(model=metadata, results=results, cached=served_from_cache)


@app.post("/model/reload")
async def reload_model(_: None = Depends(auth_dependency)) -> Dict[str, str]:
    """Force a reload from MLflow, bypassing the cache."""
    bundle = model_loader.get_model(force_refresh=True)
    return {
        "status": "reloaded",
        "version": bundle.version,
        "run_id": bundle.run_id,
    }
