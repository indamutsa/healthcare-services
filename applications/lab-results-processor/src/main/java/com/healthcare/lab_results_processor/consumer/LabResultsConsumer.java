package com.healthcare.lab_results_processor.consumer;

import com.healthcare.lab_results_processor.dto.EnrichedClinicalMessage;
import com.healthcare.lab_results_processor.service.LabResultsProcessingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Component;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.TextMessage;

/**
 * JMS Consumer for lab results from CLINICAL.LAB.RESULTS queue
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class LabResultsConsumer {
    
    private final LabResultsProcessingService processingService;
    
    /**
     * Listen for lab results from the CLINICAL.LAB.RESULTS queue
     * Spring automatically deserializes JSON to EnrichedClinicalMessage using Jackson
     */
    @JmsListener(destination = "${lab.results.queue.name}")
    public void processLabResult(String message) {
        try {
            System.out.println("Hello world =====>>>>> : " + message);
            // log.info("Received lab result message - ProcessingID: {}, DataType: {}", 
            //         enrichedMessage.getProcessingId(), enrichedMessage.getDataType());
            
            // // Extract the original payload
            // var payload = enrichedMessage.getOriginalPayload();
            // if (payload == null) {
            //     log.warn("No originalPayload found in enriched message - ProcessingID: {}", 
            //             enrichedMessage.getProcessingId());
            //     return;
            // }
            
            // // Validate that this is actually a lab result
            // if (!"LAB_RESULT".equals(payload.getDataType()) || payload.getLabResult() == null) {
            //     log.warn("Received message without lab result data - ProcessingID: {}, Type: {}", 
            //             enrichedMessage.getProcessingId(), payload.getDataType());
            //     return;
            // }
            
            // log.info("Processing lab result - Patient: {}, Test: {}, Value: {}", 
            //          payload.getLabResult().getPatientId(),
            //          payload.getLabResult().getTestType(),
            //          payload.getLabResult().getResultValue());
            
            // // Process the lab result
            // processingService.processLabResult(payload);
            
            // log.info("Successfully processed lab result - ProcessingID: {}, Patient: {}, Test: {}", 
            //         enrichedMessage.getProcessingId(),
            //         payload.getLabResult().getPatientId(),
            //         payload.getLabResult().getTestType());
            
        } catch (Exception e) {
            log.error("Error processing lab result message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process lab result", e);
        }
    }
    
    /**
     * Handle failed message processing
     */
    @JmsListener(destination = "CLINICAL.BACKOUT")
    public void handleFailedMessage(Message message) {
        try {
            String messageId = message.getJMSMessageID();
            log.error("Received failed lab result message in backout queue - ID: {}", messageId);
            
            if (message instanceof TextMessage textMessage) {
                String messageBody = textMessage.getText();
                log.error("Failed message content: {}", messageBody);
                
                // Could implement retry logic or alert mechanisms here
                processingService.handleFailedMessage(messageId, messageBody);
            }
            
        } catch (JMSException e) {
            log.error("Error handling failed message: {}", e.getMessage(), e);
        }
    }
}