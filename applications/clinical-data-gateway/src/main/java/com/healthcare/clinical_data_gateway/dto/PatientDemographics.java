package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import javax.validation.constraints.*;

/**
 * Patient demographic information (HIPAA compliant - anonymized)
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PatientDemographics {
    
    @NotBlank(message = "Patient ID is required")
    @JsonProperty("patient_id")
    private String patientId;
    
    @Min(value = 18, message = "Age must be at least 18")
    @Max(value = 120, message = "Age must be less than 120")
    @JsonProperty("age")
    private Integer age;
    
    @NotBlank(message = "Gender is required")
    @JsonProperty("gender")
    private String gender;
    
    @NotBlank(message = "Ethnicity is required")
    @JsonProperty("ethnicity")
    private String ethnicity;
    
    @DecimalMin(value = "30.0", message = "Weight must be at least 30kg")
    @DecimalMax(value = "300.0", message = "Weight must be less than 300kg")
    @JsonProperty("weight_kg")
    private Double weightKg;
    
    @DecimalMin(value = "100.0", message = "Height must be at least 100cm")
    @DecimalMax(value = "250.0", message = "Height must be less than 250cm")
    @JsonProperty("height_cm")
    private Double heightCm;
    
    @NotBlank(message = "Study ID is required")
    @JsonProperty("study_id")
    private String studyId;
    
    @NotBlank(message = "Enrollment date is required")
    @JsonProperty("enrollment_date")
    private String enrollmentDate;
}