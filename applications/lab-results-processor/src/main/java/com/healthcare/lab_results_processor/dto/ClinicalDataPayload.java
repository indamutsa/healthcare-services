package com.healthcare.lab_results_processor.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Main payload for clinical trial data.
 * Contains message metadata and one of the specific clinical data types.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ClinicalDataPayload {
    
    @NotBlank(message = "Message ID is required")
    @JsonProperty("message_id")
    private String messageId;
    
    @NotNull(message = "Timestamp is required")
    private String timestamp;
    
    @NotBlank(message = "Study phase is required")
    @JsonProperty("study_phase")
    private String studyPhase;
    
    @NotBlank(message = "Site ID is required")
    @JsonProperty("site_id")
    private String siteId;
    
    // Optional clinical data - only one should be present per message
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
    
    /**
     * Determines the type of clinical data contained in this payload
     */
    public String getDataType() {
        if (patientDemographics != null) return "DEMOGRAPHICS";
        if (vitalSigns != null) return "VITAL_SIGNS";
        if (labResult != null) return "LAB_RESULT";
        if (adverseEvent != null) return "ADVERSE_EVENT";
        return "UNKNOWN";
    }
    
    /**
     * Gets the patient ID from whichever data type is present
     */
    public String getPatientId() {
        if (patientDemographics != null) return patientDemographics.getPatientId();
        if (vitalSigns != null) return vitalSigns.getPatientId();
        if (labResult != null) return labResult.getPatientId();
        if (adverseEvent != null) return adverseEvent.getPatientId();
        return null;
    }
    
    /**
     * Validates that exactly one clinical data type is present
     */
    public boolean hasValidDataStructure() {
        int dataTypeCount = 0;
        if (patientDemographics != null) dataTypeCount++;
        if (vitalSigns != null) dataTypeCount++;
        if (labResult != null) dataTypeCount++;
        if (adverseEvent != null) dataTypeCount++;
        
        return dataTypeCount == 1; // Exactly one data type should be present
    }
    
    /**
     * Get lab result data
     */
    public LabResult getLabResult() {
        return labResult;
    }
}