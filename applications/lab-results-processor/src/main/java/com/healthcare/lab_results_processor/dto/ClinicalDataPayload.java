package com.healthcare.lab_results_processor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Complete clinical data payload from the gateway
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClinicalDataPayload {
    
    @JsonProperty("message_id")
    private String messageId;
    
    private String timestamp;
    
    @JsonProperty("study_phase")
    private String studyPhase;
    
    @JsonProperty("site_id")
    private String siteId;
    
    @JsonProperty("lab_result")
    private LabResultMessage labResult;
    
    /**
     * Check if this payload contains lab result data
     */
    public boolean hasLabResult() {
        return labResult != null;
    }
    
    /**
     * Get the primary data type in the payload
     */
    public String getDataType() {
        if (labResult != null) {
            return "LAB_RESULT";
        }
        return "UNKNOWN";
    }
}