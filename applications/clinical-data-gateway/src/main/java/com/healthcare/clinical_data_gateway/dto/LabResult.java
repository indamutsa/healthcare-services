package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import javax.validation.constraints.*;

/**
 * Laboratory test result
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class LabResult {
    
    @NotBlank(message = "Patient ID is required")
    @JsonProperty("patient_id")
    private String patientId;
    
    @NotBlank(message = "Test type is required")
    @JsonProperty("test_type")
    private String testType;
    
    @NotNull(message = "Result value is required")
    @DecimalMin(value = "0.0", message = "Result value must be positive")
    @JsonProperty("result_value")
    private Double resultValue;
    
    @NotBlank(message = "Unit is required")
    @JsonProperty("unit")
    private String unit;
    
    @NotBlank(message = "Reference range is required")
    @JsonProperty("reference_range")
    private String referenceRange;
    
    @NotBlank(message = "Test date is required")
    @JsonProperty("test_date")
    private String testDate;
    
    @NotBlank(message = "Lab technician ID is required")
    @JsonProperty("lab_technician_id")
    private String labTechnicianId;
    
    @NotNull(message = "Abnormal flag is required")
    @JsonProperty("is_abnormal")
    private Boolean isAbnormal;
}