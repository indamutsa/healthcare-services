package com.healthcare.clinical_data_gateway.dto;
import com.fasterxml.jackson.annotation.JsonProperty;
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


/**
 * Patient demographic information (anonymized for HIPAA compliance)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PatientDemographics {
    
    @NotBlank(message = "Patient ID is required")
    @Pattern(regexp = "^PT[A-Z0-9]{8}$", message = "Patient ID must follow format PT########")
    @JsonProperty("patient_id")
    private String patientId;
    
    @NotNull(message = "Age is required")
    @Min(value = 18, message = "Patient must be at least 18 years old")
    @Max(value = 120, message = "Age must be realistic")
    private Integer age;
    
    @NotBlank(message = "Gender is required")
    @Pattern(regexp = "^(Male|Female|Other)$", message = "Gender must be Male, Female, or Other")
    private String gender;
    
    @NotBlank(message = "Ethnicity is required")
    private String ethnicity;
    
    @NotNull(message = "Weight is required")
    @DecimalMin(value = "30.0", message = "Weight must be at least 30 kg")
    @DecimalMax(value = "300.0", message = "Weight must be less than 300 kg")
    @JsonProperty("weight_kg")
    private Double weightKg;
    
    @NotNull(message = "Height is required")
    @DecimalMin(value = "100.0", message = "Height must be at least 100 cm")
    @DecimalMax(value = "250.0", message = "Height must be less than 250 cm")
    @JsonProperty("height_cm")
    private Double heightCm;
    
    @NotBlank(message = "Study ID is required")
    @JsonProperty("study_id")
    private String studyId;
    
    @NotNull(message = "Enrollment date is required")
    @JsonProperty("enrollment_date")
    private String enrollmentDate;
    
    /**
     * Calculate BMI from height and weight
     */
    public double calculateBmi() {
        if (weightKg == null || heightCm == null) {
            return 0.0;
        }
        double heightMeters = heightCm / 100.0;
        return Math.round((weightKg / (heightMeters * heightMeters)) * 10.0) / 10.0;
    }
    
    /**
     * Get BMI category based on standard ranges
     */
    public String getBmiCategory() {
        double bmi = calculateBmi();
        if (bmi < 18.5) return "Underweight";
        if (bmi < 25.0) return "Normal";
        if (bmi < 30.0) return "Overweight";
        return "Obese";
    }
}
