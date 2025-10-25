"""
Kafka Monitoring Operator for Clinical Trials MLOps Pipeline
Handles Kafka topic monitoring, consumer lag detection, and data flow validation
"""

import logging
import time
from typing import Dict, Any, Optional, List

# Conditional imports for Airflow
try:
    from airflow.models import BaseOperator
    from airflow.utils.decorators import apply_defaults
    from airflow.exceptions import AirflowException
    AIRFLOW_AVAILABLE = True
except ImportError:
    # Fallback for development/testing without Airflow
    class BaseOperator:
        def __init__(self, *args, **kwargs):
            self.log = logging.getLogger(__name__)
    
    def apply_defaults(func):
        return func
    
    class AirflowException(Exception):
        pass
    
    AIRFLOW_AVAILABLE = False


class KafkaTopicMonitorOperator(BaseOperator):
    """
    Monitors Kafka topics for clinical data flow and health
    """
    
    @apply_defaults
    def __init__(
        self,
        kafka_connection_id: str = "kafka_default",
        topics: List[str] = None,
        expected_message_rate: int = 100,
        alert_threshold: int = 10,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.kafka_connection_id = kafka_connection_id
        self.topics = topics or ["clinical_data", "lab_results", "adverse_events"]
        self.expected_message_rate = expected_message_rate
        self.alert_threshold = alert_threshold
    
    def execute(self, context):
        try:
            # Get Kafka connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                kafka_conn = BaseHook.get_connection(self.kafka_connection_id)
            
            self.log.info(f"Monitoring Kafka topics: {self.topics}")
            
            # Monitor each topic
            monitoring_results = {}
            for topic in self.topics:
                topic_status = self._monitor_topic(topic)
                monitoring_results[topic] = topic_status
                
                if topic_status["healthy"]:
                    self.log.info(f"Topic {topic} is healthy")
                else:
                    self.log.warning(f"Topic {topic} has issues: {topic_status['issues']}")
            
            return monitoring_results
            
        except Exception as e:
            self.log.error(f"Failed to monitor Kafka topics: {str(e)}")
            raise AirflowException(f"Kafka topic monitoring failed: {str(e)}")
    
    def _monitor_topic(self, topic: str) -> Dict[str, Any]:
        """Monitor a single Kafka topic"""
        # Simulate topic monitoring
        # In production, this would use kafka-python or confluent-kafka
        issues = []
        
        # Check topic exists
        topic_exists = True  # Simulated
        if not topic_exists:
            issues.append(f"Topic {topic} does not exist")
        
        # Check message rate
        current_rate = 95  # Simulated
        if current_rate < self.expected_message_rate * 0.5:
            issues.append(f"Low message rate: {current_rate} messages/min")
        
        # Check consumer lag
        consumer_lag = 5  # Simulated
        if consumer_lag > self.alert_threshold:
            issues.append(f"High consumer lag: {consumer_lag} messages")
        
        return {
            "topic": topic,
            "healthy": len(issues) == 0,
            "issues": issues,
            "message_rate": current_rate,
            "consumer_lag": consumer_lag
        }


class KafkaConsumerLagSensor(BaseOperator):
    """
    Sensor to detect and alert on Kafka consumer lag
    """
    
    @apply_defaults
    def __init__(
        self,
        kafka_connection_id: str = "kafka_default",
        consumer_group: str = "clinical_data_consumers",
        topic: str = "clinical_data",
        max_lag_threshold: int = 100,
        timeout: int = 300,
        poke_interval: int = 30,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.kafka_connection_id = kafka_connection_id
        self.consumer_group = consumer_group
        self.topic = topic
        self.max_lag_threshold = max_lag_threshold
        self.timeout = timeout
        self.poke_interval = poke_interval
    
    def execute(self, context):
        try:
            self.log.info(f"Monitoring consumer lag for group {self.consumer_group} on topic {self.topic}")
            
            start_time = time.time()
            
            while time.time() - start_time < self.timeout:
                # Check consumer lag
                current_lag = self._get_consumer_lag()
                
                if current_lag <= self.max_lag_threshold:
                    self.log.info(f"Consumer lag is acceptable: {current_lag}")
                    return True
                else:
                    self.log.warning(f"High consumer lag detected: {current_lag}. Waiting for it to reduce...")
                    time.sleep(self.poke_interval)
            
            raise AirflowException(f"Consumer lag did not reduce below threshold within timeout")
            
        except Exception as e:
            self.log.error(f"Failed to monitor consumer lag: {str(e)}")
            raise AirflowException(f"Consumer lag monitoring failed: {str(e)}")
    
    def _get_consumer_lag(self) -> int:
        """Get current consumer lag"""
        # Simulate consumer lag check
        # In production, this would query Kafka consumer metrics
        return 50  # Simulated lag


class KafkaDataValidatorOperator(BaseOperator):
    """
    Validates Kafka message schemas and data quality for clinical data
    """
    
    @apply_defaults
    def __init__(
        self,
        kafka_connection_id: str = "kafka_default",
        topic: str = "clinical_data",
        sample_size: int = 10,
        schema_validation: bool = True,
        data_quality_checks: List[str] = None,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.kafka_connection_id = kafka_connection_id
        self.topic = topic
        self.sample_size = sample_size
        self.schema_validation = schema_validation
        self.data_quality_checks = data_quality_checks or [
            "missing_values",
            "data_types",
            "value_ranges",
            "required_fields"
        ]
    
    def execute(self, context):
        try:
            # Get Kafka connection
            if AIRFLOW_AVAILABLE:
                from airflow.hooks.base import BaseHook
                kafka_conn = BaseHook.get_connection(self.kafka_connection_id)
            
            self.log.info(f"Validating data quality for topic {self.topic}")
            
            # Sample messages for validation
            sample_messages = self._sample_messages()
            
            # Perform validation
            validation_results = self._validate_messages(sample_messages)
            
            if validation_results["valid"]:
                self.log.info(f"Data validation passed for topic {self.topic}")
            else:
                self.log.warning(f"Data validation issues found: {validation_results['issues']}")
            
            return validation_results
            
        except Exception as e:
            self.log.error(f"Failed to validate Kafka data: {str(e)}")
            raise AirflowException(f"Kafka data validation failed: {str(e)}")
    
    def _sample_messages(self) -> List[Dict]:
        """Sample messages from Kafka topic"""
        # Simulate message sampling
        # In production, this would consume messages from Kafka
        return [
            {
                "patient_id": "P001",
                "measurement": 120.5,
                "timestamp": "2024-01-01T10:00:00Z"
            },
            {
                "patient_id": "P002", 
                "measurement": 118.2,
                "timestamp": "2024-01-01T10:01:00Z"
            }
        ]
    
    def _validate_messages(self, messages: List[Dict]) -> Dict[str, Any]:
        """Validate sampled messages"""
        issues = []
        
        for i, message in enumerate(messages):
            # Check required fields
            required_fields = ["patient_id", "measurement", "timestamp"]
            for field in required_fields:
                if field not in message:
                    issues.append(f"Message {i}: Missing required field '{field}'")
            
            # Check data types
            if "measurement" in message and not isinstance(message["measurement"], (int, float)):
                issues.append(f"Message {i}: Invalid measurement type")
            
            # Check value ranges
            if "measurement" in message and isinstance(message["measurement"], (int, float)):
                if message["measurement"] <= 0:
                    issues.append(f"Message {i}: Invalid measurement value {message['measurement']}")
        
        return {
            "valid": len(issues) == 0,
            "issues": issues,
            "messages_checked": len(messages),
            "checks_performed": self.data_quality_checks
        }