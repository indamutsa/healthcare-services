package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Patient vital signs measurement data
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VitalSigns {
    
    @NotBlank(message = "Patient ID is required")
    @Pattern(regexp = "^PT[A-Z0-9]{8}$", message = "Patient ID must follow format PT########")
    private String patientId;
    
    @NotNull(message = "Measurement time is required")
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    private LocalDateTime measurementTime;
    
    @NotNull(message = "Systolic blood pressure is required")
    @Min(value = 60, message = "Systolic BP must be at least 60 mmHg")
    @Max(value = 250, message = "Systolic BP must be less than 250 mmHg")
    private Integer systolicBp;
    
    @NotNull(message = "Diastolic blood pressure is required")
    @Min(value = 40, message = "Diastolic BP must be at least 40 mmHg")
    @Max(value = 150, message = "Diastolic BP must be less than 150 mmHg")
    private Integer diastolicBp;
    
    @NotNull(message = "Heart rate is required")
    @Min(value = 30, message = "Heart rate must be at least 30 bpm")
    @Max(value = 200, message = "Heart rate must be less than 200 bpm")
    private Integer heartRate;
    
    @NotNull(message = "Temperature is required")
    @DecimalMin(value = "35.0", message = "Temperature must be at least 35°C")
    @DecimalMax(value = "42.0", message = "Temperature must be less than 42°C")
    private Double temperatureCelsius;
    
    @NotNull(message = "Respiratory rate is required")
    @Min(value = 8, message = "Respiratory rate must be at least 8/min")
    @Max(value = 40, message = "Respiratory rate must be less than 40/min")
    private Integer respiratoryRate;
    
    @NotNull(message = "Oxygen saturation is required")
    @Min(value = 70, message = "Oxygen saturation must be at least 70%")
    @Max(value = 100, message = "Oxygen saturation cannot exceed 100%")
    private Integer oxygenSaturation;
    
    /**
     * Calculate pulse pressure (systolic - diastolic)
     */
    public int getPulsePressure() {
        return systolicBp - diastolicBp;
    }
    
    /**
     * Calculate mean arterial pressure
     */
    public double getMeanArterialPressure() {
        return Math.round((diastolicBp + (getPulsePressure() / 3.0)) * 10.0) / 10.0;
    }
    
    /**
     * Check if vital signs indicate critical condition
     */
    public boolean isCritical() {
        return systolicBp < 90 || systolicBp > 180 ||
               diastolicBp < 60 || diastolicBp > 110 ||
               heartRate < 50 || heartRate > 120 ||
               temperatureCelsius < 36.0 || temperatureCelsius > 38.5 ||
               respiratoryRate < 12 || respiratoryRate > 25 ||
               oxygenSaturation < 95;
    }
    
    /**
     * Get blood pressure category
     */
    public String getBloodPressureCategory() {
        if (systolicBp < 120 && diastolicBp < 80) return "Normal";
        if (systolicBp < 130 && diastolicBp < 80) return "Elevated";
        if (systolicBp < 140 || diastolicBp < 90) return "Stage 1 Hypertension";
        if (systolicBp < 180 || diastolicBp < 120) return "Stage 2 Hypertension";
        return "Hypertensive Crisis";
    }
}