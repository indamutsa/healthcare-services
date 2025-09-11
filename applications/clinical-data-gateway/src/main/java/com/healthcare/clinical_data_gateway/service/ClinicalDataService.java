package com.healthcare.clinical_data_gateway.service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.clinical_data_gateway.dto.ClinicalDataPayload;
import com.healthcare.clinical_data_gateway.exception.ClinicalDataException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Service for processing clinical trial data and sending to JMS queues
 * Handles business logic, validation, and message routing
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ClinicalDataService {
    
    private final JmsTemplate jmsTemplate;
    private final ValidationService validationService;
    private final ObjectMapper objectMapper;
    
    @Value("${clinical.jms.queues.vital-signs:CLINICAL.VITAL.SIGNS}")
    private String vitalSignsQueue;
    
    @Value("${clinical.jms.queues.lab-results:CLINICAL.LAB.RESULTS}")
    private String labResultsQueue;
    
    @Value("${clinical.jms.queues.adverse-events:CLINICAL.ADVERSE.EVENTS}")
    private String adverseEventsQueue;
    
    @Value("${clinical.jms.queues.demographics:CLINICAL.DEMOGRAPHICS}")
    private String demographicsQueue;
    
    @Value("${clinical.jms.queues.priority:CLINICAL.PRIORITY}")
    private String priorityQueue;
    
    /**
     * Process clinical data payload and route to appropriate queue
     * Returns a processing ID for tracking
     */
    @Transactional
    public String processClinicalData(ClinicalDataPayload payload) {
        try {
            // Generate unique processing ID
            String processingId = generateProcessingId();
            
            // Validate the payload
            if (!validationService.validateClinicalPayload(payload)) {
                throw new ClinicalDataException("Payload validation failed");
            }
            
            // Enrich payload with processing metadata
            Map<String, Object> enrichedPayload = enrichPayload(payload, processingId);
            
            // Route to appropriate queue based on data type and priority
            String targetQueue = determineTargetQueue(payload);
            
            // Send to JMS queue
            sendToQueue(targetQueue, enrichedPayload);
            
            // Log successful processing
            log.info("Clinical data processed successfully - ProcessingID: {}, Queue: {}, Type: {}", 
                    processingId, targetQueue, payload.getDataType());
            
            return processingId;
            
        } catch (Exception e) {
            log.error("Failed to process clinical data - MessageID: {}, Error: {}", 
                    payload.getMessageId(), e.getMessage(), e);
            throw new ClinicalDataException("Failed to process clinical data: " + e.getMessage(), e);
        }
    }
    
    /**
     * Validate payload structure and content
     */
    public boolean validatePayload(ClinicalDataPayload payload) {
        return validationService.validateClinicalPayload(payload);
    }
    
    /**
     * Get queue health status for monitoring
     */
    public Map<String, Object> getQueueHealthStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("vitalSignsQueue", checkQueueHealth(vitalSignsQueue));
        status.put("labResultsQueue", checkQueueHealth(labResultsQueue));
        status.put("adverseEventsQueue", checkQueueHealth(adverseEventsQueue));
        status.put("demographicsQueue", checkQueueHealth(demographicsQueue));
        status.put("priorityQueue", checkQueueHealth(priorityQueue));
        status.put("overall", "HEALTHY"); // Simplified for demo
        return status;
    }
    
    /**
     * Determine target queue based on data type and priority
     */
    private String determineTargetQueue(ClinicalDataPayload payload) {
        // Check if this is a priority message (critical lab results, severe adverse events)
        if (isPriorityMessage(payload)) {
            log.info("Routing to priority queue - MessageID: {}, Reason: {}", 
                    payload.getMessageId(), getPriorityReason(payload));
            return priorityQueue;
        }
        
        // Route based on data type
        return switch (payload.getDataType()) {
            case "VITAL_SIGNS" -> vitalSignsQueue;
            case "LAB_RESULT" -> labResultsQueue;
            case "ADVERSE_EVENT" -> adverseEventsQueue;
            case "DEMOGRAPHICS" -> demographicsQueue;
            default -> throw new ClinicalDataException("Unknown data type: " + payload.getDataType());
        };
    }
    
    /**
     * Check if message should be routed to priority queue
     */
    private boolean isPriorityMessage(ClinicalDataPayload payload) {
        switch (payload.getDataType()) {
            case "VITAL_SIGNS":
                return payload.getVitalSigns().isCritical();
            case "LAB_RESULT":
                return payload.getLabResult().requiresImmediateAttention();
            case "ADVERSE_EVENT":
                return payload.getAdverseEvent().requiresImmediateReporting();
            default:
                return false;
        }
    }
    
    /**
     * Get reason for priority routing
     */
    private String getPriorityReason(ClinicalDataPayload payload) {
        switch (payload.getDataType()) {
            case "VITAL_SIGNS":
                return "Critical vital signs detected";
            case "LAB_RESULT":
                return "Critical lab result: " + payload.getLabResult().getSeverityLevel();
            case "ADVERSE_EVENT":
                return "Serious adverse event: " + payload.getAdverseEvent().getSeverity();
            default:
                return "Unknown priority reason";
        }
    }
    
    /**
     * Enrich payload with processing metadata
     */
    private Map<String, Object> enrichPayload(ClinicalDataPayload payload, String processingId) {
        Map<String, Object> enriched = new HashMap<>();
        
        // Original payload data
        enriched.put("originalPayload", payload);
        
        // Processing metadata
        enriched.put("processingId", processingId);
        enriched.put("processedAt", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        enriched.put("processedBy", "clinical-data-gateway");
        enriched.put("version", "1.0");
        
        // Message routing information
        enriched.put("dataType", payload.getDataType());
        enriched.put("patientId", payload.getPatientId());
        enriched.put("siteId", payload.getSiteId());
        enriched.put("studyPhase", payload.getStudyPhase());
        enriched.put("priority", isPriorityMessage(payload));
        
        // Clinical context
        if (isPriorityMessage(payload)) {
            enriched.put("priorityReason", getPriorityReason(payload));
            enriched.put("clinicalAlert", true);
        }
        
        return enriched;
    }
    
    /**
     * Send message to specified JMS queue
     */
    private void sendToQueue(String queueName, Map<String, Object> payload) {
        try {
            String jsonMessage = objectMapper.writeValueAsString(payload);
            
            jmsTemplate.convertAndSend(queueName, jsonMessage, message -> {
                // Set JMS message properties for routing and processing
                message.setStringProperty("MessageType", "ClinicalData");
                message.setStringProperty("DataType", (String) payload.get("dataType"));
                message.setStringProperty("ProcessingId", (String) payload.get("processingId"));
                message.setStringProperty("PatientId", (String) payload.get("patientId"));
                message.setStringProperty("SiteId", (String) payload.get("siteId"));
                message.setBooleanProperty("Priority", (Boolean) payload.getOrDefault("priority", false));
                
                // Set message expiration (24 hours for clinical data)
                message.setJMSExpiration(System.currentTimeMillis() + (24 * 60 * 60 * 1000));
                
                return message;
            });
            
            log.debug("Message sent to queue {} - ProcessingID: {}", 
                    queueName, payload.get("processingId"));
            
        } catch (JsonProcessingException e) {
            throw new ClinicalDataException("Failed to serialize message payload", e);
        } catch (Exception e) {
            throw new ClinicalDataException("Failed to send message to queue: " + queueName, e);
        }
    }
    
    /**
     * Generate unique processing ID
     */
    private String generateProcessingId() {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        String uuid = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        return "PROC-" + timestamp + "-" + uuid;
    }
    
    /**
     * Check health of individual queue (simplified for demo)
     */
    private String checkQueueHealth(String queueName) {
        try {
            // In a real implementation, you would check queue depth, connectivity, etc.
            // For demo purposes, we'll just return HEALTHY
            return "HEALTHY";
        } catch (Exception e) {
            log.error("Queue health check failed for {}: {}", queueName, e.getMessage());
            return "UNHEALTHY";
        }
    }
}