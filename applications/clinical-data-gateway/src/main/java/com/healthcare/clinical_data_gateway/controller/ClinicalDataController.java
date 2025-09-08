package com.healthcare.clinical_data_gateway.controller;

import com.healthcare.clinical_data_gateway.dto.ClinicalDataPayload;
import com.healthcare.clinical_data_gateway.service.ClinicalDataService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * REST controller for receiving clinical trial data
 * Accepts clinical data via HTTP and forwards to JMS queues
 */
@RestController
@RequestMapping("/api/clinical")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*") // For demo purposes - restrict in production
public class ClinicalDataController {
    
    private final ClinicalDataService clinicalDataService;
    private final MeterRegistry meterRegistry;
    
    /**
     * Primary endpoint for receiving clinical trial data
     * Accepts JSON payload and forwards to appropriate JMS queue
     */
    @PostMapping("/data")
    public ResponseEntity<Map<String, Object>> receiveClinicalData(
            @Valid @RequestBody ClinicalDataPayload payload) {
        
        Timer.Sample timer = Timer.start(meterRegistry);
        
        // Increment counters
        Counter.builder("clinical_data_received_total")
                .description("Total number of clinical data messages received")
                .tag("service", "clinical-data-gateway")
                .register(meterRegistry)
                .increment();
        
        log.info("Received clinical data - ID: {}, Type: {}, Patient: {}, Site: {}", 
                payload.getMessageId(), payload.getDataType(), 
                payload.getPatientId(), payload.getSiteId());
        
        try {
            // Process the clinical data through service layer
            String processingId = clinicalDataService.processClinicalData(payload);
            
            // Create success response
            Map<String, Object> response = createSuccessResponse(payload, processingId);
            
            // Increment success counter
            Counter.builder("clinical_data_processed_total")
                    .description("Total number of clinical data messages processed successfully")
                    .tag("service", "clinical-data-gateway")
                    .register(meterRegistry)
                    .increment();
            
            log.info("Successfully processed clinical data - ID: {}, ProcessingID: {}", 
                    payload.getMessageId(), processingId);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            // Increment error counter
            Counter.builder("clinical_data_errors_total")
                    .description("Total number of clinical data processing errors")
                    .tag("service", "clinical-data-gateway")
                    .register(meterRegistry)
                    .increment();
            
            log.error("Error processing clinical data - ID: {}, Error: {}", 
                    payload.getMessageId(), e.getMessage(), e);
            
            Map<String, Object> errorResponse = createErrorResponse(payload, e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
            
        } finally {
            timer.stop(Timer.builder("clinical_data_processing_duration")
                    .description("Time taken to process clinical data")
                    .tag("service", "clinical-data-gateway")
                    .register(meterRegistry));
        }
    }
    
    /**
     * Health check endpoint specifically for clinical data processing
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> healthCheck() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "UP");
        health.put("service", "clinical-data-gateway");
        health.put("timestamp", LocalDateTime.now());
        health.put("queueStatus", clinicalDataService.getQueueHealthStatus());
        
        return ResponseEntity.ok(health);
    }
    
    /**
     * Get processing statistics for monitoring
     */
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getProcessingStats() {
        Map<String, Object> stats = new HashMap<>();
        
        // Get metrics from registry
        Counter receivedCounter = meterRegistry.find("clinical_data_received_total").counter();
        Counter processedCounter = meterRegistry.find("clinical_data_processed_total").counter();
        Counter errorCounter = meterRegistry.find("clinical_data_errors_total").counter();
        Timer processingTimer = meterRegistry.find("clinical_data_processing_duration").timer();
        
        stats.put("messagesReceived", receivedCounter != null ? receivedCounter.count() : 0);
        stats.put("messagesProcessed", processedCounter != null ? processedCounter.count() : 0);
        stats.put("processingErrors", errorCounter != null ? errorCounter.count() : 0);
        stats.put("successRate", calculateSuccessRate(receivedCounter, processedCounter));
        stats.put("averageProcessingTime", processingTimer != null ? processingTimer.mean(TimeUnit.MILLISECONDS) : 0);
        stats.put("timestamp", LocalDateTime.now());
        
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Endpoint to test data validation without processing
     * Useful for testing and debugging
     */
    @PostMapping("/validate")
    public ResponseEntity<Map<String, Object>> validateClinicalData(
            @Valid @RequestBody ClinicalDataPayload payload) {
        
        log.info("Validating clinical data - ID: {}, Type: {}", 
                payload.getMessageId(), payload.getDataType());
        
        try {
            // Validate the payload structure and content
            boolean isValid = clinicalDataService.validatePayload(payload);
            
            Map<String, Object> response = new HashMap<>();
            response.put("messageId", payload.getMessageId());
            response.put("valid", isValid);
            response.put("dataType", payload.getDataType());
            response.put("patientId", payload.getPatientId());
            response.put("validationTimestamp", LocalDateTime.now());
            
            if (isValid) {
                response.put("message", "Clinical data payload is valid");
                return ResponseEntity.ok(response);
            } else {
                response.put("message", "Clinical data payload validation failed");
                return ResponseEntity.badRequest().body(response);
            }
            
        } catch (Exception e) {
            log.error("Error validating clinical data - ID: {}, Error: {}", 
                    payload.getMessageId(), e.getMessage());
            
            Map<String, Object> errorResponse = createErrorResponse(payload, e.getMessage());
            return ResponseEntity.badRequest().body(errorResponse);
        }
    }
    
    /**
     * Create standardized success response
     */
    private Map<String, Object> createSuccessResponse(ClinicalDataPayload payload, String processingId) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "SUCCESS");
        response.put("messageId", payload.getMessageId());
        response.put("processingId", processingId);
        response.put("dataType", payload.getDataType());
        response.put("patientId", payload.getPatientId());
        response.put("siteId", payload.getSiteId());
        response.put("processedAt", LocalDateTime.now());
        response.put("message", "Clinical data received and queued for processing");
        
        return response;
    }
    
    /**
     * Create standardized error response
     */
    private Map<String, Object> createErrorResponse(ClinicalDataPayload payload, String errorMessage) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "ERROR");
        response.put("messageId", payload != null ? payload.getMessageId() : "unknown");
        response.put("error", errorMessage);
        response.put("timestamp", LocalDateTime.now());
        response.put("message", "Failed to process clinical data");
        
        return response;
    }
    
    /**
     * Calculate success rate percentage
     */
    private double calculateSuccessRate(Counter receivedCounter, Counter processedCounter) {
        if (receivedCounter == null || receivedCounter.count() == 0) return 0.0;
        if (processedCounter == null) return 0.0;
        
        double received = receivedCounter.count();
        double processed = processedCounter.count();
        return Math.round((processed / received) * 100.0 * 100.0) / 100.0;
    }
}