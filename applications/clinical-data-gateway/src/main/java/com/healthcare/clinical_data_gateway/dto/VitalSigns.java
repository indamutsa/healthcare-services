package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import javax.validation.constraints.*;

/**
 * Patient vital signs measurement
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class VitalSigns {
    
    @NotBlank(message = "Patient ID is required")
    @JsonProperty("patient_id")
    private String patientId;
    
    @NotBlank(message = "Measurement time is required")
    @JsonProperty("measurement_time")
    private String measurementTime;
    
    @Min(value = 50, message = "Systolic BP must be at least 50")
    @Max(value = 250, message = "Systolic BP must be less than 250")
    @JsonProperty("systolic_bp")
    private Integer systolicBp;
    
    @Min(value = 30, message = "Diastolic BP must be at least 30")
    @Max(value = 150, message = "Diastolic BP must be less than 150")
    @JsonProperty("diastolic_bp")
    private Integer diastolicBp;
    
    @Min(value = 30, message = "Heart rate must be at least 30")
    @Max(value = 200, message = "Heart rate must be less than 200")
    @JsonProperty("heart_rate")
    private Integer heartRate;
    
    @DecimalMin(value = "32.0", message = "Temperature must be at least 32°C")
    @DecimalMax(value = "45.0", message = "Temperature must be less than 45°C")
    @JsonProperty("temperature_celsius")
    private Double temperatureCelsius;
    
    @Min(value = 5, message = "Respiratory rate must be at least 5")
    @Max(value = 40, message = "Respiratory rate must be less than 40")
    @JsonProperty("respiratory_rate")
    private Integer respiratoryRate;
    
    @Min(value = 70, message = "Oxygen saturation must be at least 70%")
    @Max(value = 100, message = "Oxygen saturation cannot exceed 100%")
    @JsonProperty("oxygen_saturation")
    private Integer oxygenSaturation;
}