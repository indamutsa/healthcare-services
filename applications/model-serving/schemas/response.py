"""Response schemas for prediction endpoints."""

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class ModelMetadata(BaseModel):
    """Information about the served model."""

    name: str
    version: str
    stage: str
    run_id: str
    loaded_at: datetime


class PredictionResult(BaseModel):
    """Prediction output for a single record."""

    patient_id: Optional[str] = None
    probability: float = Field(..., ge=0.0, le=1.0)
    predicted_class: int = Field(..., ge=0, le=1)
    threshold: float = Field(..., ge=0.0, le=1.0)
    metadata: Optional[Dict[str, Any]] = None
    explanation: Optional[Dict[str, float]] = None


class PredictionResponse(BaseModel):
    """Response wrapper for batch predictions."""

    model: ModelMetadata
    results: List[PredictionResult]
    cached: bool = Field(False, description="Indicates whether predictions were served from cache")
