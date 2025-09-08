package com.healthcare.clinical_data_gateway.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * Adverse event report for clinical trials
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdverseEvent {
    
    @NotBlank(message = "Patient ID is required")
    @Pattern(regexp = "^PT[A-Z0-9]{8}$", message = "Patient ID must follow format PT########")
    private String patientId;
    
    @NotBlank(message = "Event description is required")
    private String eventDescription;
    
    @NotBlank(message = "Severity is required")
    @Pattern(regexp = "^(Mild|Moderate|Severe)$", message = "Severity must be Mild, Moderate, or Severe")
    private String severity;
    
    @NotNull(message = "Start date is required")
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    private LocalDateTime startDate;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    private LocalDateTime endDate;
    
    @NotNull(message = "Study drug relationship flag is required")
    private Boolean relatedToStudyDrug;
    
    @NotBlank(message = "Action taken is required")
    private String actionTaken;
    
    /**
     * Check if the adverse event is currently ongoing
     */
    public boolean isOngoing() {
        return endDate == null;
    }
    
    /**
     * Calculate duration of the adverse event in days
     */
    public long getDurationInDays() {
        LocalDateTime end = endDate != null ? endDate : LocalDateTime.now();
        return ChronoUnit.DAYS.between(startDate, end);
    }
    
    /**
     * Calculate duration in hours for ongoing or short events
     */
    public long getDurationInHours() {
        LocalDateTime end = endDate != null ? endDate : LocalDateTime.now();
        return ChronoUnit.HOURS.between(startDate, end);
    }
    
    /**
     * Get the severity level as integer for processing
     */
    public int getSeverityLevel() {
        return switch (severity) {
            case "Mild" -> 1;
            case "Moderate" -> 2;
            case "Severe" -> 3;
            default -> 0;
        };
    }
    
    /**
     * Determine if this is a Serious Adverse Event (SAE)
     * Based on ICH-GCP guidelines
     */
    public boolean isSeriousAdverseEvent() {
        // For demo purposes, consider severe events lasting > 24 hours as serious
        // In real clinical trials, SAE criteria are more complex
        return "Severe".equals(severity) && getDurationInHours() > 24;
    }
    
    /**
     * Check if immediate reporting is required
     */
    public boolean requiresImmediateReporting() {
        return isSeriousAdverseEvent() || 
               (relatedToStudyDrug && "Severe".equals(severity));
    }
    
    /**
     * Get regulatory classification for reporting
     */
    public String getRegulatoryClassification() {
        if (isSeriousAdverseEvent()) {
            return relatedToStudyDrug ? "Serious Adverse Drug Reaction" : "Serious Adverse Event";
        } else {
            return relatedToStudyDrug ? "Adverse Drug Reaction" : "Adverse Event";
        }
    }
    
    /**
     * Get recommended follow-up action based on severity and drug relationship
     */
    public String getRecommendedFollowUp() {
        if (isSeriousAdverseEvent()) {
            return "Immediate medical evaluation and regulatory reporting required";
        }
        
        return switch (severity) {
            case "Severe" -> "Medical evaluation within 24 hours";
            case "Moderate" -> "Clinical assessment within 48 hours";
            case "Mild" -> "Monitor and document at next visit";
            default -> "Standard monitoring";
        };
    }
}