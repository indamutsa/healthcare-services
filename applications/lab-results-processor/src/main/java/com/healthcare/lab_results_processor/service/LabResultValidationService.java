package com.healthcare.lab_results_processor.service;

import com.healthcare.lab_results_processor.dto.LabResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * Service for validating lab results
 */
@Service
@Slf4j
public class LabResultValidationService {
    
    /**
     * Validate a lab result message
     */
    public void validateLabResult(LabResult labResult) {
        List<String> errors = new ArrayList<>();
        
        // Validate patient ID
        if (labResult.getPatientId() == null || labResult.getPatientId().trim().isEmpty()) {
            errors.add("Patient ID is required");
        } else if (!labResult.getPatientId().matches("^PT[A-Z0-9]{8}$")) {
            errors.add("Patient ID must follow format PT########");
        }
        
        // Validate test type
        if (labResult.getTestType() == null || labResult.getTestType().trim().isEmpty()) {
            errors.add("Test type is required");
        } else if (!isValidTestType(labResult.getTestType())) {
            errors.add("Invalid test type: " + labResult.getTestType());
        }
        
        // Validate result value
        if (labResult.getResultValue() == null) {
            errors.add("Result value is required");
        } else if (labResult.getResultValue() < 0) {
            errors.add("Result value must be positive");
        }
        
        // Validate unit
        if (labResult.getUnit() == null || labResult.getUnit().trim().isEmpty()) {
            errors.add("Unit is required");
        }
        
        // Validate reference range
        if (labResult.getReferenceRange() == null || labResult.getReferenceRange().trim().isEmpty()) {
            errors.add("Reference range is required");
        }
        
        // Validate test date
        if (labResult.getTestDate() == null || labResult.getTestDate().trim().isEmpty()) {
            errors.add("Test date is required");
        }
        
        // Validate lab technician ID
        if (labResult.getLabTechnicianId() == null || labResult.getLabTechnicianId().trim().isEmpty()) {
            errors.add("Lab technician ID is required");
        } else if (!labResult.getLabTechnicianId().matches("^LAB[0-9]{4}$")) {
            errors.add("Lab technician ID must follow format LAB####");
        }
        
        // Validate abnormal flag
        if (labResult.getIsAbnormal() == null) {
            errors.add("Abnormal flag is required");
        }
        
        // Validate result value ranges for specific test types
        if (labResult.getTestType() != null && labResult.getResultValue() != null) {
            validateTestSpecificRanges(labResult, errors);
        }
        
        if (!errors.isEmpty()) {
            String errorMessage = "Lab result validation failed: " + String.join(", ", errors);
            log.error("Validation errors for patient {}: {}", labResult.getPatientId(), errorMessage);
            throw new IllegalArgumentException(errorMessage);
        }
        
        log.debug("Lab result validation passed for patient: {}, test: {}", 
                 labResult.getPatientId(), labResult.getTestType());
    }
    
    /**
     * Check if the test type is valid
     */
    private boolean isValidTestType(String testType) {
        return testType.matches("^(Blood Glucose|Cholesterol|Hemoglobin|White Blood Cell Count|Creatinine|Liver Enzyme \\(ALT\\))$");
    }
    
    /**
     * Validate test-specific value ranges
     */
    private void validateTestSpecificRanges(LabResult labResult, List<String> errors) {
        String testType = labResult.getTestType();
        Double value = labResult.getResultValue();
        
        switch (testType) {
            case "Blood Glucose":
                if (value < 10 || value > 500) {
                    errors.add("Blood glucose value must be between 10-500 mg/dL");
                }
                break;
                
            case "Cholesterol":
                if (value < 50 || value > 1000) {
                    errors.add("Cholesterol value must be between 50-1000 mg/dL");
                }
                break;
                
            case "Hemoglobin":
                if (value < 3 || value > 25) {
                    errors.add("Hemoglobin value must be between 3-25 g/dL");
                }
                break;
                
            case "White Blood Cell Count":
                if (value < 500 || value > 50000) {
                    errors.add("White blood cell count must be between 500-50000 cells/μL");
                }
                break;
                
            case "Creatinine":
                if (value < 0.1 || value > 15.0) {
                    errors.add("Creatinine value must be between 0.1-15.0 mg/dL");
                }
                break;
                
            case "Liver Enzyme (ALT)":
                if (value < 1 || value > 1000) {
                    errors.add("ALT value must be between 1-1000 U/L");
                }
                break;
        }
    }
}