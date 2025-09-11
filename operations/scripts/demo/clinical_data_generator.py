#!/usr/bin/env python3
"""
Clinical Data Generator for Healthcare Clinical Trials Platform

This module generates realistic clinical trial data and displays it in the terminal.
The data includes patient demographics, vital signs, lab results, and adverse events.

DEMO MODE: Currently configured to show generated data without making HTTP calls.
To enable REST API calls, uncomment the HTTP request code in the send_data() method.

Usage:
    python clinical_data_generator.py --count 10 --interval 2-5
    python clinical_data_generator.py --verbose  # For detailed logging
"""

import json
import random
import time
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import requests
from dataclasses import dataclass, asdict
from enum import Enum
import argparse
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class StudyPhase(Enum):
    """Clinical trial phases"""
    PHASE_I = "Phase I"
    PHASE_II = "Phase II" 
    PHASE_III = "Phase III"
    PHASE_IV = "Phase IV"


class EventSeverity(Enum):
    """Adverse event severity levels"""
    MILD = "Mild"
    MODERATE = "Moderate"
    SEVERE = "Severe"


class LabTestType(Enum):
    """Types of laboratory tests"""
    BLOOD_GLUCOSE = "Blood Glucose"
    CHOLESTEROL = "Cholesterol"
    HEMOGLOBIN = "Hemoglobin"
    WHITE_BLOOD_CELL = "White Blood Cell Count"
    CREATININE = "Creatinine"
    LIVER_ENZYME = "Liver Enzyme (ALT)"


@dataclass
class PatientDemographics:
    """Patient demographic information (anonymized for HIPAA compliance)"""
    patient_id: str
    age: int
    gender: str
    ethnicity: str
    weight_kg: float
    height_cm: float
    study_id: str
    enrollment_date: str


@dataclass
class VitalSigns:
    """Patient vital signs measurement"""
    patient_id: str
    measurement_time: str
    systolic_bp: int
    diastolic_bp: int
    heart_rate: int
    temperature_celsius: float
    respiratory_rate: int
    oxygen_saturation: int


@dataclass
class LabResult:
    """Laboratory test result"""
    patient_id: str
    test_type: str
    result_value: float
    unit: str
    reference_range: str
    test_date: str
    lab_technician_id: str
    is_abnormal: bool


@dataclass
class AdverseEvent:
    """Adverse event report"""
    patient_id: str
    event_description: str
    severity: str
    start_date: str
    end_date: Optional[str]
    related_to_study_drug: bool
    action_taken: str


@dataclass
class ClinicalDataPayload:
    """Complete clinical data payload"""
    message_id: str
    timestamp: str
    study_phase: str
    site_id: str
    patient_demographics: Optional[PatientDemographics] = None
    vital_signs: Optional[VitalSigns] = None
    lab_result: Optional[LabResult] = None
    adverse_event: Optional[AdverseEvent] = None


class ClinicalDataGenerator:
    """Generates realistic clinical trial data"""
    
    def __init__(self):
        self.study_sites = ["SITE001", "SITE002", "SITE003", "SITE004", "SITE005"]
        self.study_ids = ["CARDIO2024", "ONCOLOGY2024", "DIABETES2024", "RESPIRATORY2024"]
        self.patient_pool = self._generate_patient_pool()
        
    def _generate_patient_pool(self) -> List[str]:
        """Generate a pool of anonymous patient IDs"""
        return [f"PT{str(uuid.uuid4())[:8].upper()}" for _ in range(50)]
    
    def generate_patient_demographics(self) -> PatientDemographics:
        """Generate realistic patient demographic data"""
        patient_id = random.choice(self.patient_pool)
        
        # Generate realistic demographic data
        age = random.randint(18, 85)
        gender = random.choice(["Male", "Female", "Other"])
        ethnicity = random.choice([
            "Caucasian", "African American", "Hispanic", "Asian", 
            "Native American", "Pacific Islander", "Other"
        ])
        
        # Realistic weight and height distributions
        if gender == "Male":
            weight_kg = round(random.normalvariate(80, 15), 1)
            height_cm = round(random.normalvariate(175, 10), 1)
        else:
            weight_kg = round(random.normalvariate(65, 12), 1)
            height_cm = round(random.normalvariate(162, 8), 1)
        
        return PatientDemographics(
            patient_id=patient_id,
            age=age,
            gender=gender,
            ethnicity=ethnicity,
            weight_kg=max(40, weight_kg),  # Minimum realistic weight
            height_cm=max(140, height_cm),  # Minimum realistic height
            study_id=random.choice(self.study_ids),
            enrollment_date=(datetime.now() - timedelta(days=random.randint(1, 365))).isoformat()
        )
    
    def generate_vital_signs(self) -> VitalSigns:
        """Generate realistic vital signs"""
        patient_id = random.choice(self.patient_pool)
        
        # Generate realistic vital signs with some variation
        systolic_bp = random.randint(90, 180)
        diastolic_bp = random.randint(60, min(systolic_bp - 20, 110))
        heart_rate = random.randint(50, 120)
        temperature = round(random.normalvariate(37.0, 0.5), 1)
        respiratory_rate = random.randint(12, 24)
        oxygen_sat = random.randint(95, 100)
        
        return VitalSigns(
            patient_id=patient_id,
            measurement_time=datetime.now().isoformat(),
            systolic_bp=systolic_bp,
            diastolic_bp=diastolic_bp,
            heart_rate=heart_rate,
            temperature_celsius=temperature,
            respiratory_rate=respiratory_rate,
            oxygen_saturation=oxygen_sat
        )
    
    def generate_lab_result(self) -> LabResult:
        """Generate realistic laboratory test results"""
        patient_id = random.choice(self.patient_pool)
        test_type = random.choice(list(LabTestType)).value
        
        # Generate test-specific values and ranges
        test_configs = {
            "Blood Glucose": {"range": (70, 200), "unit": "mg/dL", "ref_range": "70-100 mg/dL"},
            "Cholesterol": {"range": (150, 300), "unit": "mg/dL", "ref_range": "<200 mg/dL"},
            "Hemoglobin": {"range": (10, 18), "unit": "g/dL", "ref_range": "12-16 g/dL"},
            "White Blood Cell Count": {"range": (3000, 15000), "unit": "cells/μL", "ref_range": "4500-11000 cells/μL"},
            "Creatinine": {"range": (0.5, 3.0), "unit": "mg/dL", "ref_range": "0.7-1.3 mg/dL"},
            "Liver Enzyme (ALT)": {"range": (10, 100), "unit": "U/L", "ref_range": "7-56 U/L"}
        }
        
        config = test_configs[test_type]
        result_value = round(random.uniform(*config["range"]), 2)
        
        # Determine if result is abnormal (20% chance)
        is_abnormal = random.random() < 0.2
        
        return LabResult(
            patient_id=patient_id,
            test_type=test_type,
            result_value=result_value,
            unit=config["unit"],
            reference_range=config["ref_range"],
            test_date=datetime.now().isoformat(),
            lab_technician_id=f"LAB{random.randint(1000, 9999)}",
            is_abnormal=is_abnormal
        )
    
    def generate_adverse_event(self) -> AdverseEvent:
        """Generate realistic adverse event reports"""
        patient_id = random.choice(self.patient_pool)
        
        # Common adverse events in clinical trials
        events = [
            "Headache", "Nausea", "Dizziness", "Fatigue", "Rash",
            "Diarrhea", "Insomnia", "Muscle pain", "Joint pain",
            "Decreased appetite", "Vomiting", "Constipation"
        ]
        
        actions = [
            "No action taken", "Dose reduced", "Treatment discontinued",
            "Medication administered", "Monitoring increased", "Symptomatic treatment"
        ]
        
        severity = random.choice(list(EventSeverity)).value
        start_date = datetime.now() - timedelta(days=random.randint(0, 7))
        
        # 60% chance event has resolved
        end_date = None
        if random.random() < 0.6:
            end_date = (start_date + timedelta(days=random.randint(1, 14))).isoformat()
        
        return AdverseEvent(
            patient_id=patient_id,
            event_description=random.choice(events),
            severity=severity,
            start_date=start_date.isoformat(),
            end_date=end_date,
            related_to_study_drug=random.random() < 0.3,  # 30% chance related to study drug
            action_taken=random.choice(actions)
        )
    
    def generate_clinical_payload(self) -> ClinicalDataPayload:
        """Generate a complete clinical data payload"""
        message_id = str(uuid.uuid4())
        study_phase = random.choice(list(StudyPhase)).value
        site_id = random.choice(self.study_sites)
        
        # Randomly choose what type of data to generate (weights for realistic distribution)
        data_type = random.choices(
            ["vital_signs", "lab_result", "adverse_event", "demographics"],
            weights=[40, 30, 15, 15]  # Vital signs most common
        )[0]
        
        payload = ClinicalDataPayload(
            message_id=message_id,
            timestamp=datetime.now().isoformat(),
            study_phase=study_phase,
            site_id=site_id
        )
        
        # Add specific data type
        if data_type == "vital_signs":
            payload.vital_signs = self.generate_vital_signs()
        elif data_type == "lab_result":
            payload.lab_result = self.generate_lab_result()
        elif data_type == "adverse_event":
            payload.adverse_event = self.generate_adverse_event()
        elif data_type == "demographics":
            payload.patient_demographics = self.generate_patient_demographics()
        
        return payload


class ClinicalDataSender:
    """Sends clinical data to the REST API"""
    
    def __init__(self, endpoint_url: str):
        self.endpoint_url = endpoint_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'ClinicalDataGenerator/1.0'
        })
    
    def send_data(self, payload: ClinicalDataPayload) -> bool:
        """Send clinical data payload to the REST API"""
        try:
            # Convert dataclass to dict, handling nested objects
            data = self._serialize_payload(payload)
            logger.info(data) 
            response = self.session.post(
                f"{self.endpoint_url}/api/clinical/data",
                json=data,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info(f"✅ Successfully sent {payload.message_id} - "
                          f"Type: {self._get_data_type(payload)}")
                return True
            else:
                logger.error(f"❌ Failed to send {payload.message_id} - "
                           f"Status: {response.status_code}, Response: {response.text}")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Network error sending {payload.message_id}: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Unexpected error sending {payload.message_id}: {e}")
            return False
    
    def _serialize_payload(self, payload: ClinicalDataPayload) -> Dict:
        """Convert dataclass payload to JSON-serializable dict"""
        result = asdict(payload)
        # Remove None values to keep payload clean
        return {k: v for k, v in result.items() if v is not None}
    
    def _get_data_type(self, payload: ClinicalDataPayload) -> str:
        """Determine the primary data type in the payload"""
        if payload.vital_signs:
            return "Vital Signs"
        elif payload.lab_result:
            return f"Lab Result ({payload.lab_result.test_type})"
        elif payload.adverse_event:
            return f"Adverse Event ({payload.adverse_event.severity})"
        elif payload.patient_demographics:
            return "Patient Demographics"
        return "Unknown"


def main():
    """Main function to run the clinical data generator"""
    parser = argparse.ArgumentParser(description='Generate clinical trial data')
    parser.add_argument('--endpoint', default='http://localhost:8080',
                       help='Clinical data gateway endpoint URL')
    parser.add_argument('--interval', default='1-5',
                       help='Random interval range in seconds (e.g., 1-5)')
    parser.add_argument('--count', type=int, default=0,
                       help='Number of messages to send (0 for infinite)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Parse interval range
    try:
        interval_parts = args.interval.split('-')
        if len(interval_parts) == 2:
            min_interval, max_interval = map(int, interval_parts)
        else:
            min_interval = max_interval = int(interval_parts[0])
    except ValueError:
        logger.error("Invalid interval format. Use format like '5-15' or '10'")
        return
    
    generator = ClinicalDataGenerator()
    sender = ClinicalDataSender(args.endpoint)
    
    logger.info(f"🏥 Starting Clinical Data Generator")
    logger.info(f"📡 Endpoint: {args.endpoint}")
    logger.info(f"⏱️  Interval: {min_interval}-{max_interval} seconds")
    logger.info(f"📊 Messages: {'infinite' if args.count == 0 else args.count}")
    
    message_count = 0
    success_count = 0
    
    try:
        while args.count == 0 or message_count < args.count:
            # Generate clinical data payload
            payload = generator.generate_clinical_payload()
            
            # Send to REST API
            if sender.send_data(payload):
                success_count += 1
            
            message_count += 1
            
            # Log progress every 10 messages
            if message_count % 10 == 0:
                success_rate = (success_count / message_count) * 100
                logger.info(f"📈 Progress: {message_count} sent, "
                          f"{success_rate:.1f}% success rate")
            
            # Wait for random interval
            if args.count == 0 or message_count < args.count:
                wait_time = random.randint(min_interval, max_interval)
                logger.debug(f"⏳ Waiting {wait_time} seconds...")
                time.sleep(wait_time)
    
    except KeyboardInterrupt:
        logger.info("\n🛑 Stopped by user")
    
    except Exception as e:
        logger.error(f"💥 Unexpected error: {e}")
    
    finally:
        success_rate = (success_count / message_count) * 100 if message_count > 0 else 0
        logger.info(f"\n📊 Final Statistics:")
        logger.info(f"   Total messages: {message_count}")
        logger.info(f"   Successful: {success_count}")
        logger.info(f"   Success rate: {success_rate:.1f}%")


if __name__ == "__main__":
    main()