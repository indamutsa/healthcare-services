"""
Kafka producer for clinical trial data simulation.
Contains both data generation logic and Kafka producer orchestration.
"""

import os
import time
import json
import random
import logging
from datetime import datetime, timedelta
from typing import Dict
import numpy as np
from faker import Faker
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

fake = Faker()


# =============================================================================
# DATA GENERATOR - Business Logic (What data looks like)
# =============================================================================

class ClinicalDataGenerator:
    """
    Generates synthetic clinical trial data.
    Handles all medical domain logic and realistic patient simulation.
    """
    
    def __init__(self, num_patients: int = 1000):
        """
        Initialize data generator.
        
        Args:
            num_patients: Number of unique patients to simulate
        """
        self.num_patients = num_patients
        self.patient_ids = [f"PT{str(i).zfill(5)}" for i in range(1, num_patients + 1)]
        
        # Generate patient demographics using Faker
        self.patient_demographics = {
            pid: {
                "age": random.randint(18, 85),
                "gender": random.choice(["M", "F"]),
                "site": fake.city(),
                "enrollment_date": fake.date_between(start_date="-2y", end_date="today"),
                "trial_arm": random.choice(["treatment", "control"])
            }
            for pid in self.patient_ids
        }
        
        # Patient baseline vitals (each patient has their own "normal")
        # Age affects baseline - older patients have different vital patterns
        self.patient_baselines = {}
        for pid in self.patient_ids:
            age = self.patient_demographics[pid]["age"]
            age_factor = (age - 40) / 100  # Normalized age effect
            
            self.patient_baselines[pid] = {
                "heart_rate": np.random.normal(75 - age_factor * 10, 10),
                "bp_systolic": np.random.normal(120 + age_factor * 20, 15),
                "bp_diastolic": np.random.normal(80 + age_factor * 10, 10),
                "temperature": np.random.normal(37.0, 0.3),
                "spo2": np.random.normal(98 - age_factor * 2, 1.5)
            }
        
        # Drug library with realistic dosages
        self.medications = [
            {"name": "Metformin", "dosage": 500, "unit": "mg", "frequency": "BID"},
            {"name": "Lisinopril", "dosage": 10, "unit": "mg", "frequency": "QD"},
            {"name": "Atorvastatin", "dosage": 20, "unit": "mg", "frequency": "QD"},
            {"name": "Aspirin", "dosage": 81, "unit": "mg", "frequency": "QD"},
            {"name": "Levothyroxine", "dosage": 50, "unit": "mcg", "frequency": "QD"},
            {"name": "Omeprazole", "dosage": 20, "unit": "mg", "frequency": "QD"},
            {"name": "Amlodipine", "dosage": 5, "unit": "mg", "frequency": "QD"},
            {"name": "Metoprolol", "dosage": 25, "unit": "mg", "frequency": "BID"},
        ]
        
        # Lab test definitions with normal ranges
        self.lab_tests = [
            {"name": "ALT", "normal_range": (7, 56), "unit": "U/L"},
            {"name": "AST", "normal_range": (10, 40), "unit": "U/L"},
            {"name": "Creatinine", "normal_range": (0.7, 1.3), "unit": "mg/dL"},
            {"name": "Glucose", "normal_range": (70, 100), "unit": "mg/dL"},
            {"name": "Hemoglobin", "normal_range": (13.5, 17.5), "unit": "g/dL"},
            {"name": "Platelets", "normal_range": (150, 400), "unit": "10^3/uL"},
            {"name": "WBC", "normal_range": (4.5, 11.0), "unit": "10^3/uL"},
            {"name": "BUN", "normal_range": (7, 20), "unit": "mg/dL"},
        ]
        
        # Adverse event types (rare but critical)
        self.adverse_events = [
            "liver_toxicity",
            "kidney_dysfunction",
            "severe_hypotension",
            "arrhythmia",
            "anaphylaxis",
            "thrombocytopenia",
            "neutropenia",
            "qt_prolongation"
        ]
        
        # Clinician names for realistic reporting
        self.clinicians = [fake.name() for _ in range(20)]
        
        logger.info(f"Initialized generator with {num_patients} patients")
    
    def generate_vitals(self) -> Dict:
        """
        Generate patient vital signs with realistic variation.
        Uses random walk around patient baseline to simulate natural fluctuation.
        """
        patient_id = random.choice(self.patient_ids)
        baseline = self.patient_baselines[patient_id]
        demographics = self.patient_demographics[patient_id]
        
        # Add random walk variation (vitals don't jump drastically)
        vitals = {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "heart_rate": int(np.clip(baseline["heart_rate"] + np.random.normal(0, 5), 40, 200)),
            "blood_pressure_systolic": int(np.clip(baseline["bp_systolic"] + np.random.normal(0, 10), 60, 250)),
            "blood_pressure_diastolic": int(np.clip(baseline["bp_diastolic"] + np.random.normal(0, 5), 40, 150)),
            "temperature": round(np.clip(baseline["temperature"] + np.random.normal(0, 0.2), 35.0, 42.0), 1),
            "spo2": int(np.clip(baseline["spo2"] + np.random.normal(0, 1), 70, 100)),
            "source": random.choice(["bedside_monitor", "manual_entry", "icu_monitor", "telemetry"]),
            "trial_site": demographics["site"],
            "trial_arm": demographics["trial_arm"]
        }
        
        # 5% chance of abnormal vitals (early warning signal)
        if random.random() < 0.05:
            anomaly_type = random.choice(["high_hr", "low_bp", "fever", "hypoxia"])
            if anomaly_type == "high_hr":
                vitals["heart_rate"] = random.randint(120, 180)
            elif anomaly_type == "low_bp":
                vitals["blood_pressure_systolic"] = random.randint(70, 90)
                vitals["blood_pressure_diastolic"] = random.randint(40, 60)
            elif anomaly_type == "fever":
                vitals["temperature"] = round(random.uniform(38.5, 40.0), 1)
            elif anomaly_type == "hypoxia":
                vitals["spo2"] = random.randint(85, 92)
        
        return vitals
    
    def generate_lab_result(self) -> Dict:
        """
        Generate lab test result.
        90% normal, 10% abnormal to simulate realistic patterns.
        """
        patient_id = random.choice(self.patient_ids)
        test = random.choice(self.lab_tests)
        demographics = self.patient_demographics[patient_id]
        
        # 90% normal, 10% abnormal
        if random.random() < 0.9:
            value = round(random.uniform(*test["normal_range"]), 2)
        else:
            # Abnormal value (outside range)
            if random.random() < 0.5:
                value = round(test["normal_range"][0] * random.uniform(0.5, 0.9), 2)
            else:
                value = round(test["normal_range"][1] * random.uniform(1.1, 1.5), 2)
        
        return {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "test_name": test["name"],
            "value": value,
            "unit": test["unit"],
            "reference_range": f"{test['normal_range'][0]}-{test['normal_range'][1]}",
            "lab_id": f"LAB{random.randint(100, 999)}",
            "performing_lab": fake.company(),
            "trial_site": demographics["site"]
        }
    
    def generate_medication(self) -> Dict:
        """Generate medication administration record."""
        patient_id = random.choice(self.patient_ids)
        med = random.choice(self.medications)
        demographics = self.patient_demographics[patient_id]
        
        return {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "drug_name": med["name"],
            "dosage": med["dosage"],
            "unit": med["unit"],
            "route": random.choice(["oral", "IV", "subcutaneous", "intramuscular"]),
            "frequency": med["frequency"],
            "administered_by": random.choice(self.clinicians),
            "trial_site": demographics["site"],
            "trial_arm": demographics["trial_arm"]
        }
    
    def generate_adverse_event(self) -> Dict:
        """
        Generate adverse event (rare but critical).
        Typically reported hours after occurrence.
        """
        patient_id = random.choice(self.patient_ids)
        demographics = self.patient_demographics[patient_id]
        event_time = datetime.utcnow()
        
        return {
            "patient_id": patient_id,
            "event_timestamp": event_time.isoformat() + "Z",
            "event_type": random.choice(self.adverse_events),
            "severity": random.choice(["grade_1", "grade_2", "grade_3", "grade_4"]),
            "reported_by": random.choice(self.clinicians),
            "report_timestamp": (event_time + timedelta(hours=random.randint(1, 6))).isoformat() + "Z",
            "trial_site": demographics["site"],
            "trial_arm": demographics["trial_arm"],
            "description": fake.sentence(nb_words=10)
        }


# =============================================================================
# KAFKA PRODUCER - Infrastructure Logic (How to send data)
# =============================================================================

class ClinicalKafkaProducer:
    """
    Kafka producer for clinical trial data.
    Handles all messaging infrastructure and orchestration.
    """
    
    def __init__(
        self,
        bootstrap_servers: str,
        num_patients: int = 1000,
        message_rate: int = 100
    ):
        """
        Initialize Kafka producer.
        
        Args:
            bootstrap_servers: Kafka broker addresses (e.g., 'kafka:29092')
            num_patients: Number of patients to simulate
            message_rate: Target messages per second
        """
        self.bootstrap_servers = bootstrap_servers
        self.message_rate = message_rate
        
        # Initialize Kafka producer with JSON serialization
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            acks='all',  # Wait for all replicas
            retries=3,
            max_in_flight_requests_per_connection=1  # Ensure ordering
        )
        
        # Initialize data generator (composition)
        self.generator = ClinicalDataGenerator(num_patients=num_patients)
        
        # Topic names
        self.topics = {
            "vitals": "patient-vitals",
            "labs": "lab-results",
            "medications": "medications",
            "adverse_events": "adverse-events"
        }
        
        # Message distribution (must sum to 100)
        self.distribution = {
            "vitals": 70,        # 70% vital signs
            "medications": 20,   # 20% medication events
            "labs": 9,           # 9% lab results
            "adverse_events": 1  # 1% adverse events (rare)
        }
        
        logger.info(
            f"Initialized Kafka producer: {num_patients} patients, "
            f"{message_rate} msg/sec, brokers={bootstrap_servers}"
        )
    
    def send_message(self, topic: str, message: Dict):
        """
        Send message to Kafka topic with error handling.
        
        Args:
            topic: Kafka topic name
            message: Message payload (dict)
        """
        try:
            future = self.producer.send(topic, value=message)
            record_metadata = future.get(timeout=60)
            
            logger.debug(
                f"✓ Sent to {record_metadata.topic} "
                f"[partition={record_metadata.partition}, offset={record_metadata.offset}]"
            )
        except KafkaError as e:
            logger.error(f"✗ Failed to send message to {topic}: {e}")
    
    def run(self):
        """
        Main producer loop with:
        - Random sleep (1–10s) between batches
        - 1-hour pause after every 1000 messages
        """
        logger.info("🚀 Starting clinical data generation (randomized intervals + hourly pause)...")
        message_count = 0
        stats = {"vitals": 0, "medications": 0, "labs": 0, "adverse_events": 0}

        try:
            while True:
                start_time = time.time()

                # Randomize message rate ±20%
                dynamic_rate = int(self.message_rate * random.uniform(0.8, 1.2))

                for _ in range(dynamic_rate):
                    rand = random.randint(1, 100)

                    if rand <= self.distribution["vitals"]:
                        message = self.generator.generate_vitals()
                        topic = self.topics["vitals"]
                        stats["vitals"] += 1
                    elif rand <= self.distribution["vitals"] + self.distribution["medications"]:
                        message = self.generator.generate_medication()
                        topic = self.topics["medications"]
                        stats["medications"] += 1
                    elif rand <= (self.distribution["vitals"] +
                                self.distribution["medications"] +
                                self.distribution["labs"]):
                        message = self.generator.generate_lab_result()
                        topic = self.topics["labs"]
                        stats["labs"] += 1
                    else:
                        message = self.generator.generate_adverse_event()
                        topic = self.topics["adverse_events"]
                        stats["adverse_events"] += 1

                    self.send_message(topic, message)
                    message_count += 1

                    # After every 1000 messages, pause for one hour
                    if message_count % 1000 == 0:
                        logger.info(
                            f"⏸️  Reached {message_count} messages. "
                            f"Pausing for 2 minutes (simulating site downtime)..."
                        )
                        time.sleep(120)  # 2 minutes pause
                        logger.info("✅ Resuming data generation...")

                # Random delay between 1–10 seconds between bursts
                sleep_time = random.uniform(5, 10)
                logger.debug(f"Sleeping for {sleep_time:.2f}s before next batch...")
                time.sleep(sleep_time)

        except KeyboardInterrupt:
            logger.info("🛑 Interrupted by user. Shutting down producer...")
        finally:
            self.producer.flush()
            self.producer.close()
            logger.info(
                f"✅ Producer stopped. Total messages: {message_count} | "
                f"Final stats - Vitals: {stats['vitals']}, "
                f"Meds: {stats['medications']}, "
                f"Labs: {stats['labs']}, "
                f"Adverse: {stats['adverse_events']}"
            )




# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    # Get configuration from environment variables
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    num_patients = int(os.getenv("NUM_PATIENTS", "1000"))
    message_rate = int(os.getenv("PRODUCER_RATE", "100"))
    
    logger.info("=" * 60)
    logger.info("Clinical MLOps - Kafka Data Producer")
    logger.info("=" * 60)
    logger.info(f"Configuration:")
    logger.info(f"  • Kafka Brokers: {bootstrap_servers}")
    logger.info(f"  • Patients: {num_patients}")
    logger.info(f"  • Message Rate: {message_rate}/sec")
    logger.info(f"  • Distribution: 70% vitals, 20% meds, 9% labs, 1% adverse")
    logger.info("=" * 60)
    
    # Create and run producer
    producer = ClinicalKafkaProducer(
        bootstrap_servers=bootstrap_servers,
        num_patients=num_patients,
        message_rate=message_rate
    )
    
    producer.run()