"""Request schemas for the prediction endpoints."""

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, validator


class PredictionInstance(BaseModel):
    """Single prediction request payload."""

    patient_id: Optional[str] = Field(
        None, description="Unique identifier for the patient or entity"
    )
    timestamp: Optional[datetime] = Field(
        None, description="Event timestamp associated with the feature vector"
    )
    features: Dict[str, float] = Field(
        ..., description="Feature name to value mapping used by the model"
    )
    metadata: Optional[Dict[str, Any]] = Field(
        None, description="Additional context propagated to the response"
    )

    @validator("features")
    def _validate_features(cls, value: Dict[str, float]) -> Dict[str, float]:
        if not value:
            raise ValueError("features payload cannot be empty")
        return value


class PredictionRequest(BaseModel):
    """Prediction request supporting batch scoring."""

    records: List[PredictionInstance] = Field(..., min_items=1, description="Batch payload")
    use_cache: bool = Field(True, description="Read/write from Redis prediction cache")
