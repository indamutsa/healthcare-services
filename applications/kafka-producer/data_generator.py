"""
Synthetic clinical data generator for Kafka producer.
Generates realistic patient vitals, lab results, medications, and adverse events.
"""

import random
from datetime import datetime, timedelta
from typing import Dict
import numpy as np
from faker import Faker

fake = Faker()


class ClinicalDataGenerator:
    """Generates synthetic clinical trial data."""
    
    def __init__(self, num_patients: int = 1000):
        """
        Initialize data generator.
        
        Args:
            num_patients: Number of unique patients to simulate
        """
        self.num_patients = num_patients
        self.patient_ids = [f"PT{str(i).zfill(5)}" for i in range(1, num_patients + 1)]
        
        # Patient baseline vitals (stable state per patient)
        # Each patient has their own "normal" vital signs
        self.patient_baselines = {
            pid: {
                "heart_rate": np.random.normal(75, 10),
                "bp_systolic": np.random.normal(120, 15),
                "bp_diastolic": np.random.normal(80, 10),
                "temperature": np.random.normal(37.0, 0.3),
                "spo2": np.random.normal(98, 1.5)
            }
            for pid in self.patient_ids
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
    
    def generate_vitals(self) -> Dict:
        """
        Generate patient vital signs with realistic variation.
        Uses random walk around patient baseline to simulate natural fluctuation.
        """
        patient_id = random.choice(self.patient_ids)
        baseline = self.patient_baselines[patient_id]
        
        # Add random walk variation (vitals don't jump drastically between readings)
        vitals = {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "heart_rate": int(np.clip(baseline["heart_rate"] + np.random.normal(0, 5), 40, 200)),
            "blood_pressure_systolic": int(np.clip(baseline["bp_systolic"] + np.random.normal(0, 10), 60, 250)),
            "blood_pressure_diastolic": int(np.clip(baseline["bp_diastolic"] + np.random.normal(0, 5), 40, 150)),
            "temperature": round(np.clip(baseline["temperature"] + np.random.normal(0, 0.2), 35.0, 42.0), 1),
            "spo2": int(np.clip(baseline["spo2"] + np.random.normal(0, 1), 70, 100)),
            "source": random.choice(["bedside_monitor", "manual_entry", "icu_monitor", "telemetry"])
        }
        
        # 5% chance of abnormal vitals (early warning signal for adverse events)
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
        90% normal, 10% abnormal to simulate realistic lab patterns.
        """
        patient_id = random.choice(self.patient_ids)
        test = random.choice(self.lab_tests)
        
        # 90% normal, 10% abnormal
        if random.random() < 0.9:
            # Normal result within reference range
            value = round(random.uniform(*test["normal_range"]), 2)
        else:
            # Abnormal value (outside range)
            if random.random() < 0.5:
                # Below normal
                value = round(test["normal_range"][0] * random.uniform(0.5, 0.9), 2)
            else:
                # Above normal
                value = round(test["normal_range"][1] * random.uniform(1.1, 1.5), 2)
        
        return {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "test_name": test["name"],
            "value": value,
            "unit": test["unit"],
            "reference_range": f"{test['normal_range'][0]}-{test['normal_range'][1]}",
            "lab_id": f"LAB{random.randint(100, 999)}"
        }
    
    def generate_medication(self) -> Dict:
        """Generate medication administration record."""
        patient_id = random.choice(self.patient_ids)
        med = random.choice(self.medications)
        
        return {
            "patient_id": patient_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "drug_name": med["name"],
            "dosage": med["dosage"],
            "unit": med["unit"],
            "route": random.choice(["oral", "IV", "subcutaneous", "intramuscular"]),
            "frequency": med["frequency"]
        }
    
    def generate_adverse_event(self) -> Dict:
        """
        Generate adverse event (rare but critical).
        Typically reported hours after occurrence.
        """
        patient_id = random.choice(self.patient_ids)
        event_time = datetime.utcnow()
        
        return {
            "patient_id": patient_id,
            "event_timestamp": event_time.isoformat() + "Z",
            "event_type": random.choice(self.adverse_events),
            "severity": random.choice(["grade_1", "grade_2", "grade_3", "grade_4"]),
            "reported_by": random.choice(["clinician", "nurse", "patient", "pharmacist"]),
            "report_timestamp": (event_time + timedelta(hours=random.randint(1, 6))).isoformat() + "Z"
        }