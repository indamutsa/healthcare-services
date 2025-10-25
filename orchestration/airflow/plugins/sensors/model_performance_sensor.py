"""
Model Performance Sensor
Sensor for monitoring ML model performance and triggering retraining when needed
"""

import logging
import time
from typing import Dict, Any, Optional

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


class ModelPerformanceSensor(BaseOperator):
    """
    Sensor that monitors model performance and triggers retraining when performance degrades
    """

    @apply_defaults
    def __init__(
        self,
        model_name: str,
        performance_threshold: float = 0.80,
        metric_name: str = "accuracy",
        evaluation_window_hours: int = 24,
        poke_interval: int = 300,  # 5 minutes
        timeout: int = 7200,  # 2 hours
        mlflow_conn_id: str = "mlflow_tracking",
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.model_name = model_name
        self.performance_threshold = performance_threshold
        self.metric_name = metric_name
        self.evaluation_window_hours = evaluation_window_hours
        self.poke_interval = poke_interval
        self.timeout = timeout
        self.mlflow_conn_id = mlflow_conn_id

    def execute(self, context):
        self.log.info(f"Monitoring performance for model: {self.model_name}")
        self.log.info(f"Performance threshold: {self.performance_threshold}")
        self.log.info(f"Monitoring metric: {self.metric_name}")
        self.log.info(f"Evaluation window: {self.evaluation_window_hours} hours")

        start_time = time.time()
        attempt = 0

        while time.time() - start_time < self.timeout:
            attempt += 1
            self.log.info(f"Checking model performance (attempt {attempt})")

            try:
                performance_data = self._get_model_performance()

                current_performance = performance_data.get("current_performance", 0)
                trend = performance_data.get("performance_trend", "stable")
                data_drift = performance_data.get("data_drift_score", 0)

                self.log.info(f"Current {self.metric_name}: {current_performance:.3f}")
                self.log.info(f"Performance trend: {trend}")
                self.log.info(f"Data drift score: {data_drift:.3f}")

                # Check if retraining is needed
                retraining_needed = self._should_retrain(
                    current_performance, trend, data_drift
                )

                if retraining_needed:
                    self.log.info("Model performance degradation detected - retraining needed")
                    return {
                        "retraining_needed": True,
                        "current_performance": current_performance,
                        "threshold": self.performance_threshold,
                        "trend": trend,
                        "data_drift": data_drift,
                        "performance_data": performance_data
                    }
                else:
                    self.log.info("Model performance is acceptable")

            except Exception as e:
                self.log.error(f"Error checking model performance: {str(e)}")

            # Wait before next check
            self.log.info(f"Waiting {self.poke_interval} seconds before next check...")
            time.sleep(self.poke_interval)

        # If we reach here, timeout occurred
        self.log.info("Timeout reached, but model performance is acceptable")
        return {
            "retraining_needed": False,
            "reason": "timeout_no_degradation",
            "monitoring_duration": time.time() - start_time
        }

    def _get_model_performance(self) -> Dict[str, Any]:
        """Get current model performance metrics"""
        import random
        import datetime

        # Simulate performance monitoring
        base_performance = 0.85
        performance_degradation = random.uniform(0, 0.1)  # 0-10% degradation
        current_performance = base_performance - performance_degradation

        # Generate trend
        trends = ["improving", "stable", "degrading"]
        trend_weights = [0.1, 0.6, 0.3]  # More likely to be stable or degrading
        trend = random.choices(trends, weights=trend_weights)[0]

        # Generate data drift score
        data_drift = random.uniform(0, 0.5)

        # Simulate recent predictions
        recent_predictions = random.randint(1000, 5000)
        prediction_accuracy = random.uniform(current_performance - 0.05, current_performance + 0.05)

        return {
            "model_name": self.model_name,
            "current_performance": current_performance,
            "performance_threshold": self.performance_threshold,
            "performance_trend": trend,
            "data_drift_score": data_drift,
            "recent_predictions": {
                "count": recent_predictions,
                "accuracy": prediction_accuracy,
                "period_hours": self.evaluation_window_hours
            },
            "metrics": {
                "accuracy": current_performance,
                "precision": current_performance - random.uniform(0.02, 0.05),
                "recall": current_performance - random.uniform(0.01, 0.04),
                "f1_score": current_performance - random.uniform(0.02, 0.03),
                "auc_roc": current_performance + random.uniform(0.03, 0.08)
            },
            "last_updated": datetime.datetime.now().isoformat()
        }

    def _should_retrain(self, current_performance: float, trend: str, data_drift: float) -> bool:
        """Determine if model retraining is needed"""
        # Check performance threshold
        if current_performance < self.performance_threshold:
            self.log.info(f"Performance {current_performance:.3f} below threshold {self.performance_threshold}")
            return True

        # Check performance trend
        if trend == "degrading":
            self.log.info("Performance trend is degrading")
            return True

        # Check data drift
        if data_drift > 0.3:  # High data drift
            self.log.info(f"High data drift detected: {data_drift:.3f}")
            return True

        return False

    def poke(self, context):
        """Override poke method for sensor behavior"""
        try:
            performance_data = self._get_model_performance()
            current_performance = performance_data.get("current_performance", 0)
            trend = performance_data.get("performance_trend", "stable")
            data_drift = performance_data.get("data_drift_score", 0)

            # Check if retraining conditions are met
            if self._should_retrain(current_performance, trend, data_drift):
                self.log.info("Retraining conditions met!")
                return True

            self.log.info(f"Performance acceptable. {self.metric_name}: {current_performance:.3f}")
            return False

        except Exception as e:
            self.log.error(f"Error during poke: {str(e)}")
            return False