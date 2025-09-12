package com.healthcare.lab_results_processor.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Enriched clinical message format received from the gateway
 * Contains original payload plus processing metadata
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EnrichedClinicalMessage {
    
    @JsonProperty("originalPayload")
    private ClinicalDataPayload originalPayload;
    
    @JsonProperty("processingId")
    private String processingId;
    
    @JsonProperty("processedAt")
    private String processedAt;
    
    @JsonProperty("processedBy")
    private String processedBy;
    
    private String version;
    
    @JsonProperty("dataType")
    private String dataType;
    
    @JsonProperty("patientId")
    private String patientId;
    
    @JsonProperty("siteId")
    private String siteId;
    
    @JsonProperty("studyPhase")
    private String studyPhase;
    
    private Boolean priority;
    
    @JsonProperty("priorityReason")
    private String priorityReason;
    
    @JsonProperty("clinicalAlert")
    private Boolean clinicalAlert;
}