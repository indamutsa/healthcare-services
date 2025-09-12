package com.healthcare.clinical_data_gateway.service;

import com.healthcare.clinical_data_gateway.dto.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Service for validating clinical trial data
 * Performs business logic validation beyond basic bean validation
 */
@Service
@Slf4j
public class ValidationService {
    
    // Valid study phases for clinical trials
    private static final Set<String> VALID_STUDY_PHASES = Set.of(
            "Phase I", "Phase II", "Phase III", "Phase IV"
    );
    
    // Valid site IDs (in real system, this would be from database)
    private static final Set<String> VALID_SITE_IDS = Set.of(
            "SITE001", "SITE002", "SITE003", "SITE004", "SITE005"
    );
    
    // Valid study IDs
    private static final Set<String> VALID_STUDY_IDS = Set.of(
            "CARDIO2024", "ONCOLOGY2024", "DIABETES2024", "RESPIRATORY2024"
    );
    
    /**
     * Validate complete clinical data payload
     */
    public boolean validateClinicalPayload(ClinicalDataPayload payload) {
        List<String> validationErrors = new ArrayList<>();
        
        try {
            // Basic structure validation
            validateBasicStructure(payload, validationErrors);
            
            // Business logic validation
            validateBusinessRules(payload, validationErrors);
            
            // Data type specific validation
            validateDataTypeSpecific(payload, validationErrors);
            
            // Log validation results
            if (validationErrors.isEmpty()) {
                log.debug("Validation successful for message {}", payload.getMessageId());
                return true;
            } else {
                log.warn("Validation failed for message {} - Errors: {}", 
                        payload.getMessageId(), String.join(", ", validationErrors));
                return false;
            }
            
        } catch (Exception e) {
            log.error("Validation error for message {}: {}", payload.getMessageId(), e.getMessage());
            return false;
        }
    }
    
    /**
     * Validate basic payload structure
     */
    private void validateBasicStructure(ClinicalDataPayload payload, List<String> errors) {
        // Check that exactly one data type is present
        if (!payload.hasValidDataStructure()) {
            errors.add("Payload must contain exactly one clinical data type");
        }
        
        // Validate study phase
        if (!VALID_STUDY_PHASES.contains(payload.getStudyPhase())) {
            errors.add("Invalid study phase: " + payload.getStudyPhase());
        }
        
        // Validate site ID
        if (!VALID_SITE_IDS.contains(payload.getSiteId())) {
            errors.add("Invalid site ID: " + payload.getSiteId());
        }
        
        // TODO: Re-implement timestamp validation for String format
        // For now, just validate that timestamp is not null or empty
        if (payload.getTimestamp() == null || payload.getTimestamp().trim().isEmpty()) {
            errors.add("Timestamp cannot be null or empty");
        }
    }
    
    /**
     * Validate business rules
     */
    private void validateBusinessRules(ClinicalDataPayload payload, List<String> errors) {
        // Validate patient ID format and consistency
        String patientId = payload.getPatientId();
        if (patientId == null || patientId.trim().isEmpty()) {
            errors.add("Patient ID is required");
        }
        
        // Cross-reference study ID if demographics are present
        if (payload.getPatientDemographics() != null) {
            String studyId = payload.getPatientDemographics().getStudyId();
            if (!VALID_STUDY_IDS.contains(studyId)) {
                errors.add("Invalid study ID: " + studyId);
            }
        }
    }
    
    /**
     * Validate specific data types
     */
    private void validateDataTypeSpecific(ClinicalDataPayload payload, List<String> errors) {
        switch (payload.getDataType()) {
            case "VITAL_SIGNS":
                validateVitalSigns(payload.getVitalSigns(), errors);
                break;
            case "LAB_RESULT":
                validateLabResult(payload.getLabResult(), errors);
                break;
            case "ADVERSE_EVENT":
                validateAdverseEvent(payload.getAdverseEvent(), errors);
                break;
            case "DEMOGRAPHICS":
                validatePatientDemographics(payload.getPatientDemographics(), errors);
                break;
        }
    }
    
    /**
     * Validate vital signs specific business rules
     */
    private void validateVitalSigns(VitalSigns vitalSigns, List<String> errors) {
        // Validate blood pressure relationship
        if (vitalSigns.getSystolicBp() <= vitalSigns.getDiastolicBp()) {
            errors.add("Systolic blood pressure must be greater than diastolic");
        }
        
        // Validate pulse pressure (difference between systolic and diastolic)
        int pulsePressure = vitalSigns.getPulsePressure();
        if (pulsePressure < 20 || pulsePressure > 100) {
            errors.add("Pulse pressure out of normal range: " + pulsePressure + " mmHg");
        }
        
        // TODO: Re-implement measurement time validation for String format
        if (vitalSigns.getMeasurementTime() == null || vitalSigns.getMeasurementTime().trim().isEmpty()) {
            errors.add("Measurement time cannot be null or empty");
        }
        
        // Temperature validation - Fahrenheit to Celsius check
        if (vitalSigns.getTemperatureCelsius() > 45) {
            errors.add("Temperature appears to be in Fahrenheit - expecting Celsius");
        }
    }
    
    /**
     * Validate lab result specific business rules
     */
    private void validateLabResult(LabResult labResult, List<String> errors) {
        // TODO: Re-implement test date validation for String format
        if (labResult.getTestDate() == null || labResult.getTestDate().trim().isEmpty()) {
            errors.add("Test date cannot be null or empty");
        }
        
        // Validate test-specific value ranges
        validateLabValueRanges(labResult, errors);
        
        // Validate abnormal flag consistency
        validateAbnormalFlagConsistency(labResult, errors);
    }
    
    /**
     * Validate lab value ranges based on test type
     */
    private void validateLabValueRanges(LabResult labResult, List<String> errors) {
        String testType = labResult.getTestType();
        double value = labResult.getResultValue();
        
        switch (testType) {
            case "Blood Glucose":
                if (value < 10 || value > 500) {
                    errors.add("Blood glucose value out of plausible range: " + value);
                }
                break;
            case "Cholesterol":
                if (value < 50 || value > 500) {
                    errors.add("Cholesterol value out of plausible range: " + value);
                }
                break;
            case "Hemoglobin":
                if (value < 3 || value > 25) {
                    errors.add("Hemoglobin value out of plausible range: " + value);
                }
                break;
            case "White Blood Cell Count":
                if (value < 500 || value > 50000) {
                    errors.add("WBC count out of plausible range: " + value);
                }
                break;
            case "Creatinine":
                if (value < 0.1 || value > 10) {
                    errors.add("Creatinine value out of plausible range: " + value);
                }
                break;
            case "Liver Enzyme (ALT)":
                if (value < 1 || value > 1000) {
                    errors.add("ALT value out of plausible range: " + value);
                }
                break;
        }
    }
    
    /**
     * Validate abnormal flag matches the test result
     */
    private void validateAbnormalFlagConsistency(LabResult labResult, List<String> errors) {
        boolean expectedAbnormal = isResultAbnormal(labResult);
        if (labResult.getIsAbnormal() != expectedAbnormal) {
            errors.add("Abnormal flag inconsistent with result value for " + labResult.getTestType());
        }
    }
    
    /**
     * Determine if lab result should be flagged as abnormal
     */
    private boolean isResultAbnormal(LabResult labResult) {
        String testType = labResult.getTestType();
        double value = labResult.getResultValue();
        
        return switch (testType) {
            case "Blood Glucose" -> value < 70 || value > 100;
            case "Cholesterol" -> value > 200;
            case "Hemoglobin" -> value < 12 || value > 16;
            case "White Blood Cell Count" -> value < 4500 || value > 11000;
            case "Creatinine" -> value < 0.7 || value > 1.3;
            case "Liver Enzyme (ALT)" -> value > 56;
            default -> false;
        };
    }
    
    /**
     * Validate adverse event specific business rules
     */
    private void validateAdverseEvent(AdverseEvent adverseEvent, List<String> errors) {
        // TODO: Re-implement date validations for String format
        if (adverseEvent.getStartDate() == null || adverseEvent.getStartDate().trim().isEmpty()) {
            errors.add("Adverse event start date cannot be null or empty");
        }
        
        // Validate severe events have appropriate actions
        if ("Severe".equals(adverseEvent.getSeverity()) && 
            "No action taken".equals(adverseEvent.getActionTaken())) {
            errors.add("Severe adverse events must have documented action taken");
        }
    }
    
    /**
     * Validate patient demographics specific business rules
     */
    private void validatePatientDemographics(PatientDemographics demographics, List<String> errors) {
        // TODO: Re-implement enrollment date validation for String format
        if (demographics.getEnrollmentDate() == null || demographics.getEnrollmentDate().trim().isEmpty()) {
            errors.add("Enrollment date cannot be null or empty");
        }
        
        // Validate BMI is reasonable
        double bmi = demographics.calculateBmi();
        if (bmi < 10 || bmi > 60) {
            errors.add("Calculated BMI out of reasonable range: " + bmi);
        }
        
        // Validate height and weight relationship
        if (demographics.getHeightCm() < 130 && demographics.getWeightKg() > 100) {
            errors.add("Height and weight combination appears inconsistent");
        }
        
        // Validate age-appropriate measurements
        if (demographics.getAge() < 18) {
            errors.add("Patient age below study minimum of 18 years");
        }
    }
}