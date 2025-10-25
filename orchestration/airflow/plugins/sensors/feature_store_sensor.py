"""
Feature Store Sensor
Sensor for monitoring feature store updates and availability
"""

import logging
import time
from typing import Dict, Any, Optional, List

try:
    from airflow.models import BaseOperator
    from airflow.utils.decorators import apply_defaults
    from airflow.exceptions import AirflowException
    AIRFLOW_AVAILABLE = True
except ImportError:
    class BaseOperator:
        def __init__(self, *args, **kwargs):
            self.log = logging.getLogger(__name__)

    def apply_defaults(func):
        return func

    class AirflowException(Exception):
        pass

    AIRFLOW_AVAILABLE = False


class FeatureStoreSensor(BaseOperator):
    """
    Sensor that waits for feature store updates and monitors feature availability
    """

    @apply_defaults
    def __init__(
        self,
        feature_names: List[str],
        store_type: str = "online",  # "online" or "offline"
        min_entities: int = 100,
        max staleness_minutes: int = 60,
        poke_interval: int = 120,
        timeout: int = 3600,
        feature_store_conn_id: str = "redis_features",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.feature_names = feature_names
        self.store_type = store_type
        self.min_entities = min_entities
        self.max_staleness_minutes = max_staleness_minutes
        self.poke_interval = poke_interval
        self.timeout = timeout
        self.feature_store_conn_id = feature_store_conn_id

    def execute(self, context):
        self.log.info(f"Monitoring {self.store_type} feature store")
        self.log.info(f"Required features: {self.feature_names}")
        self.log.info(f"Minimum entities: {self.min_entities}")
        self.log.info(f"Max staleness: {self.max_staleness_minutes} minutes")

        start_time = time.time()
        attempt = 0

        while time.time() - start_time < self.timeout:
            attempt += 1
            self.log.info(f"Checking feature store status (attempt {attempt})")

            try:
                store_status = self._check_feature_store_status()

                if store_status["available"]:
                    if store_status["entity_count"] >= self.min_entities:
                        if store_status["staleness_minutes"] <= self.max_staleness_minutes:
                            missing_features = store_status["missing_features"]
                            if not missing_features:
                                self.log.info("All required features are available and fresh!")
                                self.log.info(f"Entity count: {store_status['entity_count']}")
                                self.log.info(f"Last updated: {store_status['last_updated']}")
                                return store_status
                            else:
                                self.log.warning(f"Missing features: {missing_features}")
                        else:
                            self.log.warning(f"Feature store is stale: {store_status['staleness_minutes']} minutes")
                    else:
                        self.log.warning(f"Entity count {store_status['entity_count']} below threshold {self.min_entities}")
                else:
                    self.log.warning("Feature store not available")

            except Exception as e:
                self.log.error(f"Error checking feature store: {str(e)}")

            # Wait before next check
            self.log.info(f"Waiting {self.poke_interval} seconds before next check...")
            time.sleep(self.poke_interval)

        raise AirflowException(f"Timeout waiting for {self.store_type} feature store to be ready")

    def _check_feature_store_status(self) -> Dict[str, Any]:
        """Check feature store status and availability"""
        import random
        import datetime

        # Simulate feature store status check
        is_available = random.random() > 0.2  # 80% chance store is available

        if is_available:
            # Generate mock entity count
            entity_count = random.randint(self.min_entities, self.min_entities * 10)

            # Generate staleness
            staleness = random.randint(0, self.max_staleness_minutes * 2)

            # Check which features are available
            available_features = random.sample(
                self.feature_names,
                k=random.randint(len(self.feature_names) // 2, len(self.feature_names))
            )
            missing_features = [f for f in self.feature_names if f not in available_features]

            # Generate mock statistics
            feature_stats = {}
            for feature in available_features:
                feature_stats[feature] = {
                    "null_percentage": random.uniform(0, 5),
                    "data_type": random.choice(["float", "int", "string", "boolean"]),
                    "unique_values": random.randint(10, 1000),
                    "last_updated": datetime.datetime.now().isoformat()
                }

            return {
                "available": True,
                "store_type": self.store_type,
                "entity_count": entity_count,
                "available_features": available_features,
                "missing_features": missing_features,
                "staleness_minutes": staleness,
                "last_updated": datetime.datetime.now().isoformat(),
                "feature_statistics": feature_stats,
                "store_health": {
                    "connection_status": "healthy",
                    "response_time_ms": random.randint(10, 100),
                    "memory_usage_mb": random.randint(100, 1000)
                }
            }
        else:
            return {
                "available": False,
                "reason": "Feature store connection failed",
                "error_details": "Unable to connect to Redis/MinIO",
                "retry_suggested": True
            }

    def poke(self, context):
        """Override poke method for sensor behavior"""
        try:
            store_status = self._check_feature_store_status()

            if (store_status["available"] and
                store_status["entity_count"] >= self.min_entities and
                store_status["staleness_minutes"] <= self.max_staleness_minutes and
                not store_status["missing_features"]):
                return True

            self.log.info(f"Store not ready. Available: {store_status['available']}, "
                         f"Entities: {store_status.get('entity_count', 0)}, "
                         f"Stale: {store_status.get('staleness_minutes', 0)} min, "
                         f"Missing: {store_status.get('missing_features', [])}")
            return False

        except Exception as e:
            self.log.error(f"Error during poke: {str(e)}")
            return False

    def get_feature_descriptions(self) -> Dict[str, str]:
        """Get descriptions for the required features"""
        descriptions = {
            "age": "Patient age in years",
            "bmi": "Body Mass Index",
            "avg_glucose_level": "Average blood glucose level",
            "blood_pressure_systolic": "Systolic blood pressure",
            "blood_pressure_diastolic": "Diastolic blood pressure",
            "hba1c": "Hemoglobin A1c level",
            "creatinine_level": "Serum creatinine level",
            "ldl_cholesterol": "LDL cholesterol level",
            "hdl_cholesterol": "HDL cholesterol level",
            "triglycerides": "Triglycerides level",
            "medication_count": "Number of medications",
            "comorbidity_score": "Comorbidity severity score",
            "hospital_visits_last_year": "Number of hospital visits in past year",
            "medication_adherence": "Medication adherence rate",
            "risk_score_cardiovascular": "Cardiovascular risk score",
            "risk_score_diabetes_complications": "Diabetes complications risk score"
        }

        return {feature: descriptions.get(feature, "No description available")
                for feature in self.feature_names}