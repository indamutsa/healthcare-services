package com.healthcare.clinical_data_gateway.dto;

import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

/**
 * Main payload for clinical trial data
 * Maps directly to Python ClinicalDataPayload structure
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ClinicalDataPayload {
    
    @NotBlank(message = "Message ID is required")
    @JsonProperty("message_id")
    private String messageId;
    
    @NotBlank(message = "Timestamp is required")
    @JsonProperty("timestamp")
    private String timestamp;
    
    @NotBlank(message = "Study phase is required")
    @JsonProperty("study_phase")
    private String studyPhase;
    
    @NotBlank(message = "Site ID is required")
    @JsonProperty("site_id")
    private String siteId;
    
    @Valid
    @JsonProperty("patient_demographics")
    private PatientDemographics patientDemographics;
    
    @Valid
    @JsonProperty("vital_signs")
    private VitalSigns vitalSigns;
    
    @Valid
    @JsonProperty("lab_result")
    private LabResult labResult;
    
    @Valid
    @JsonProperty("adverse_event")
    private AdverseEvent adverseEvent;
}