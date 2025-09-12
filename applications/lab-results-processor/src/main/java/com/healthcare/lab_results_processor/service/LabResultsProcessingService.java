package com.healthcare.lab_results_processor.service;

import com.healthcare.lab_results_processor.dto.ClinicalDataPayload;
import com.healthcare.lab_results_processor.dto.LabResultMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Service for processing lab results received from the queue
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LabResultsProcessingService {
    
    private final LabResultValidationService validationService;
    
    /**
     * Process a lab result from the clinical data payload
     */
    public void processLabResult(ClinicalDataPayload payload) {
        log.info("🔬 RECEIVED LAB RESULT - Message ID: {}", payload.getMessageId());
        
        LabResultMessage labResult = payload.getLabResult();
        
        try {
            // Step 1: Validate the lab result
            validationService.validateLabResult(labResult);
            log.info("✅ Lab result validation passed - Patient: {}, Test: {}", 
                     labResult.getPatientId(), labResult.getTestType());
            
            // Step 2: Print all the consumed data
            printLabResultData(payload);
            
            log.info("🎯 Lab result processing completed - Message ID: {}", payload.getMessageId());
            
        } catch (Exception e) {
            log.error("❌ Error processing lab result - Message ID: {}, Error: {}", 
                     payload.getMessageId(), e.getMessage(), e);
            throw new RuntimeException("Failed to process lab result", e);
        }
    }
    
    /**
     * Print the consumed lab result data
     */
    private void printLabResultData(ClinicalDataPayload payload) {
        LabResultMessage labResult = payload.getLabResult();
        
        log.info("=================================================");
        log.info("📊 LAB RESULT DATA CONSUMED FROM QUEUE:");
        log.info("=================================================");
        log.info("🔖 Message ID: {}", payload.getMessageId());
        log.info("⏰ Timestamp: {}", payload.getTimestamp());
        log.info("🧪 Study Phase: {}", payload.getStudyPhase());
        log.info("🏥 Site ID: {}", payload.getSiteId());
        log.info("-------------------------------------------------");
        log.info("👤 Patient ID: {}", labResult.getPatientId());
        log.info("🧬 Test Type: {}", labResult.getTestType());
        log.info("📈 Result Value: {} {}", labResult.getResultValue(), labResult.getUnit());
        log.info("📋 Reference Range: {}", labResult.getReferenceRange());
        log.info("📅 Test Date: {}", labResult.getTestDate());
        log.info("👨‍🔬 Lab Technician: {}", labResult.getLabTechnicianId());
        log.info("⚠️  Is Abnormal: {}", labResult.getIsAbnormal());
        log.info("🎯 Severity Level: {}", labResult.getSeverityLevel());
        log.info("💊 Clinical Interpretation: {}", labResult.getClinicalInterpretation());
        log.info("🚨 Requires Immediate Attention: {}", labResult.requiresImmediateAttention());
        log.info("=================================================");
        
        // Print critical alert if needed
        if (labResult.requiresImmediateAttention()) {
            log.warn("🚨🚨🚨 CRITICAL LAB RESULT DETECTED! 🚨🚨🚨");
            log.warn("Patient {} requires immediate medical attention!", labResult.getPatientId());
            log.warn("Test: {} = {} {} (Severity: {})", 
                    labResult.getTestType(), 
                    labResult.getResultValue(), 
                    labResult.getUnit(),
                    labResult.getSeverityLevel());
        }
    }
    
    /**
     * Handle a failed message from the backout queue
     */
    public void handleFailedMessage(String messageId, String messageBody) {
        log.error("🔴 Handling failed lab result message - ID: {}", messageId);
        log.error("Failed message content: {}", messageBody);
        
        // For now, just log the failure
        // Future: Could implement retry logic or send to dead letter queue
    }
}