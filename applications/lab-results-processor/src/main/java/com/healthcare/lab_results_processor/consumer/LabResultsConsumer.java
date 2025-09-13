package com.healthcare.lab_results_processor.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Component;

import jakarta.jms.JMSException;
import jakarta.jms.Message;
import jakarta.jms.TextMessage;
import java.util.Enumeration;

/**
 * JMS Consumer for lab results from CLINICAL.LAB.RESULTS queue
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class LabResultsConsumer {

    private final ObjectMapper objectMapper;
    
    /**
     * Listen for lab results from the CLINICAL.LAB.RESULTS queue
     * Spring automatically deserializes JSON to EnrichedClinicalMessage using Jackson
     */
    @JmsListener(destination = "${lab.results.queue.name}")
    public void processLabResult(String message) {
        try {
            handleAndPrint("CLINICAL.LAB.RESULTS", message);

        } catch (Exception e) {
            log.error("Error processing lab result message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process lab result", e);
        }
    }

    @JmsListener(destination = "CLINICAL.VITAL.SIGNS")
    public void processVitalSigns(String message) {
        try {
            handleAndPrint("CLINICAL.VITAL.SIGNS", message);
        } catch (Exception e) {
            log.error("Error processing vitals message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process vitals", e);
        }
    }

    @JmsListener(destination = "CLINICAL.ADVERSE.EVENTS")
    public void processAdverseEvents(String message) {
        try {
            handleAndPrint("CLINICAL.ADVERSE.EVENTS", message);
        } catch (Exception e) {
            log.error("Error processing adverse event message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process adverse event", e);
        }
    }

    @JmsListener(destination = "CLINICAL.DEMOGRAPHICS")
    public void processDemographics(String message) {
        try {
            handleAndPrint("CLINICAL.DEMOGRAPHICS", message);
        } catch (Exception e) {
            log.error("Error processing demographics message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process demographics", e);
        }
    }

    @JmsListener(destination = "CLINICAL.PRIORITY")
    public void processPriority(String message) {
        try {
            handleAndPrint("CLINICAL.PRIORITY", message);
        } catch (Exception e) {
            log.error("Error processing priority message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process priority", e);
        }
    }

    @JmsListener(destination = "CLINICAL.DEFAULT")
    public void processDefault(String message) {
        try {
            handleAndPrint("CLINICAL.DEFAULT", message);
        } catch (Exception e) {
            log.error("Error processing default queue message: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to process default queue message", e);
        }
    }

    @JmsListener(destination = "CLINICAL.DLQ")
    public void processDlq(Message message) {
        try {
            printJmsHeaders("CLINICAL.DLQ", message);
            String body = extractBody(message);
            try {
                handleAndPrint("CLINICAL.DLQ", body);
            } catch (Exception ex) {
                System.out.println("==== Queue: CLINICAL.DLQ (raw) ====");
                System.out.println(body);
                System.out.println("===================================");
                log.warn("Processed DLQ message as raw text due to error: {}", ex.getMessage());
            }
        } catch (Exception e) {
            log.error("Error processing DLQ message: {}", e.getMessage(), e);
        }
    }

    private void handleAndPrint(String queueName, String message) throws Exception {
        // Ensure mapper can handle common types and pretty-print
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        // Parse message to a generic JSON tree for schema-tolerant handling
        JsonNode root = objectMapper.readTree(message);

        // Pretty print the entire message as-is
        String pretty = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(root);
        System.out.println("==== Queue: " + queueName + " ====");
        System.out.println(pretty);
        System.out.println("===================================");

        // Only printing is required. No DTO mapping.
    }
    
    /**
     * Handle failed message processing
     */
    @JmsListener(destination = "CLINICAL.BACKOUT")
    public void handleFailedMessage(Message message) {
        try {
            printJmsHeaders("CLINICAL.BACKOUT", message);
            String body = extractBody(message);
            // Try to pretty print if JSON; otherwise print raw
            try {
                handleAndPrint("CLINICAL.BACKOUT", body);
            } catch (Exception ex) {
                System.out.println("==== Queue: CLINICAL.BACKOUT (raw) ====");
                System.out.println(body);
                System.out.println("======================================");
                log.warn("Processed BACKOUT message as raw text due to error: {}", ex.getMessage());
            }
            
        } catch (JMSException e) {
            log.error("Error handling failed message: {}", e.getMessage(), e);
        }
    }

    private void printJmsHeaders(String queueName, Message message) throws JMSException {
        System.out.println("==== JMS Headers for " + queueName + " ====");
        System.out.println("JMSMessageID: " + message.getJMSMessageID());
        System.out.println("JMSTimestamp: " + message.getJMSTimestamp());
        System.out.println("JMSCorrelationID: " + message.getJMSCorrelationID());
        System.out.println("JMSRedelivered: " + message.getJMSRedelivered());
        System.out.println("JMSDeliveryMode: " + message.getJMSDeliveryMode());
        System.out.println("JMSPriority: " + message.getJMSPriority());
        System.out.println("JMSExpiration: " + message.getJMSExpiration());
        System.out.println("JMSDestination: " + (message.getJMSDestination() != null ? message.getJMSDestination().toString() : "null"));
        System.out.println("JMSReplyTo: " + (message.getJMSReplyTo() != null ? message.getJMSReplyTo().toString() : "null"));

        try {
            @SuppressWarnings("unchecked")
            Enumeration<String> names = message.getPropertyNames();
            System.out.println("-- Properties --");
            while (names != null && names.hasMoreElements()) {
                String name = names.nextElement();
                try {
                    Object val = message.getObjectProperty(name);
                    System.out.println(name + ": " + val);
                } catch (JMSException ignore) {}
            }
        } catch (Exception ex) {
            // Ignore property enumeration issues
        }
        System.out.println("===============================");
    }

    private String extractBody(Message message) throws JMSException {
        if (message instanceof TextMessage textMessage) {
            return textMessage.getText();
        }
        return ""; // Non-text payloads are not expected in this demo
    }
}
