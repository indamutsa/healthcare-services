package com.healthcare.lab_results_processor.consumer;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.lab_results_processor.dto.ClinicalDataPayload;
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
    private final ObjectMapper objectMapper;
    
    /**
     * Listen for lab results from the CLINICAL.LAB.RESULTS queue
     */
    @JmsListener(destination = "${lab.results.queue.name}")
    public void processLabResult(Message message) {
        try {
            if (!(message instanceof TextMessage textMessage)) {
                log.warn("Received non-text message: {}", message.getClass().getSimpleName());
                return;
            }
            
            String messageBody = textMessage.getText();
            String messageId = message.getJMSMessageID();
            
            log.info("Received lab result message - ID: {}, Body length: {}", 
                    messageId, messageBody.length());
            
            // Parse the JSON message
            ClinicalDataPayload payload = objectMapper.readValue(messageBody, ClinicalDataPayload.class);
            
            // Validate that this is actually a lab result
            if (!payload.hasLabResult()) {
                log.warn("Received message without lab result data - ID: {}, Type: {}", 
                        payload.getMessageId(), payload.getDataType());
                return;
            }
            
            log.debug("Processing lab result - Patient: {}, Test: {}, Value: {}", 
                     payload.getLabResult().getPatientId(),
                     payload.getLabResult().getTestType(),
                     payload.getLabResult().getResultValue());
            
            // Process the lab result
            processingService.processLabResult(payload);
            
            log.info("Successfully processed lab result - Message ID: {}, Patient: {}, Test: {}", 
                    payload.getMessageId(),
                    payload.getLabResult().getPatientId(),
                    payload.getLabResult().getTestType());
            
        } catch (JMSException e) {
            log.error("JMS error processing lab result message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process JMS message", e);
            
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