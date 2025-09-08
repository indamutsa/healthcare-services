package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Laboratory test result data
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LabResult {
    
    @NotBlank(message = "Patient ID is required")
    @Pattern(regexp = "^PT[A-Z0-9]{8}$", message = "Patient ID must follow format PT########")
    private String patientId;
    
    @NotBlank(message = "Test type is required")
    @Pattern(regexp = "^(Blood Glucose|Cholesterol|Hemoglobin|White Blood Cell Count|Creatinine|Liver Enzyme \\(ALT\\))$",
             message = "Invalid test type")
    private String testType;
    
    @NotNull(message = "Result value is required")
    @DecimalMin(value = "0.0", message = "Result value must be positive")
    private Double resultValue;
    
    @NotBlank(message = "Unit is required")
    private String unit;
    
    @NotBlank(message = "Reference range is required")
    private String referenceRange;
    
    @NotNull(message = "Test date is required")
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    private LocalDateTime testDate;
    
    @NotBlank(message = "Lab technician ID is required")
    @Pattern(regexp = "^LAB[0-9]{4}$", message = "Lab technician ID must follow format LAB####")
    private String labTechnicianId;
    
    @NotNull(message = "Abnormal flag is required")
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