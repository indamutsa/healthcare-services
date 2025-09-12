package com.healthcare.lab_results_processor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Lab result message received from CLINICAL.LAB.RESULTS queue
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LabResultMessage {
    
    @JsonProperty("patient_id")
    private String patientId;
    
    @JsonProperty("test_type")
    private String testType;
    
    @JsonProperty("result_value")
    private Double resultValue;
    
    private String unit;
    
    @JsonProperty("reference_range")
    private String referenceRange;
    
    @JsonProperty("test_date")
    private String testDate;
    
    @JsonProperty("lab_technician_id")
    private String labTechnicianId;
    
    @JsonProperty("is_abnormal")
    private Boolean isAbnormal;
    
    /**
     * Get severity level based on test type and value
     */
    public String getSeverityLevel() {
        if (!isAbnormal) return "Normal";
        
        switch (testType) {
            case "Blood Glucose":
                if (resultValue > 200) return "Severe";
                if (resultValue > 140 || resultValue < 70) return "Moderate";
                return "Mild";
                
            case "Cholesterol":
                if (resultValue > 240) return "Severe";
                if (resultValue > 200) return "Moderate";
                return "Mild";
                
            case "Creatinine":
                if (resultValue > 3.0) return "Severe";
                if (resultValue > 1.5) return "Moderate";
                return "Mild";
                
            case "Hemoglobin":
                if (resultValue < 8 || resultValue > 18) return "Severe";
                if (resultValue < 10 || resultValue > 16) return "Moderate";
                return "Mild";
                
            case "White Blood Cell Count":
                if (resultValue < 2000 || resultValue > 20000) return "Severe";
                if (resultValue < 3500 || resultValue > 15000) return "Moderate";
                return "Mild";
                
            case "Liver Enzyme (ALT)":
                if (resultValue > 150) return "Severe";
                if (resultValue > 80) return "Moderate";
                return "Mild";
                
            default:
                return "Unknown";
        }
    }
    
    /**
     * Check if result requires immediate clinical attention
     */
    public boolean requiresImmediateAttention() {
        return "Severe".equals(getSeverityLevel());
    }
    
    /**
     * Get clinical interpretation of the result
     */
    public String getClinicalInterpretation() {
        if (!isAbnormal) return "Within normal limits";
        
        String severity = getSeverityLevel();
        return switch (severity) {
            case "Mild" -> "Slightly abnormal - monitor";
            case "Moderate" -> "Abnormal - follow-up required";
            case "Severe" -> "Critical - immediate attention required";
            default -> "Abnormal - clinical correlation advised";
        };
    }
}