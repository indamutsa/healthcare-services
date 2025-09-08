package com.healthcare.clinical_data_gateway.config;

import com.ibm.mq.jms.MQQueueConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.support.converter.MappingJackson2MessageConverter;
import org.springframework.jms.support.converter.MessageConverter;
import org.springframework.jms.support.converter.MessageType;

import jakarta.jms.ConnectionFactory;
import jakarta.jms.JMSException;

/**
 * JMS Configuration for IBM MQ integration
 * Configures connection factory, templates, and message handling for clinical data
 */
@Configuration
@EnableJms
@Slf4j
public class JmsConfig {
    
    @Value("${ibm.mq.queueManager:CLINICAL_QM}")
    private String queueManager;
    
    @Value("${ibm.mq.channel:DEV.APP.SVRCONN}")
    private String channel;
    
    @Value("${ibm.mq.connName:localhost(1414)}")
    private String connName;
    
    @Value("${ibm.mq.user:clinical_app}")
    private String user;
    
    @Value("${ibm.mq.password:clinical123}")
    private String password;
    
    @Value("${ibm.mq.clientId:clinical-data-gateway}")
    private String clientId;
    
    /**
     * IBM MQ Connection Factory configuration
     */
    @Bean
    public ConnectionFactory connectionFactory() {
        MQQueueConnectionFactory factory = new MQQueueConnectionFactory();
        
        try {
            // Basic connection settings
            factory.setQueueManager(queueManager);
            factory.setChannel(channel);
            factory.setConnectionNameList(connName);
            factory.setClientID(clientId);
            
            // Authentication
            factory.setStringProperty(WMQConstants.USERID, user);
            factory.setStringProperty(WMQConstants.PASSWORD, password);
            
            // Transport type - use client mode for remote connections
            factory.setTransportType(WMQConstants.WMQ_CM_CLIENT);
            
            // SSL configuration for production (disabled for demo)
            factory.setStringProperty(WMQConstants.WMQ_SSL_CIPHER_SUITE, "");
            
            // Connection pooling and performance settings
            factory.setStringProperty(WMQConstants.WMQ_APPLICATIONNAME, "ClinicalDataGateway");
            factory.setIntProperty(WMQConstants.WMQ_CLIENT_RECONNECT_OPTIONS, WMQConstants.WMQ_CLIENT_RECONNECT);
            factory.setIntProperty(WMQConstants.WMQ_CLIENT_RECONNECT_TIMEOUT, 300); // 5 minutes
            
            // Message handling options
            factory.setBooleanProperty(WMQConstants.USER_AUTHENTICATION_MQCSP, true);
            factory.setStringProperty(WMQConstants.WMQ_PROVIDER_VERSION, "8.0.0.0");
            
            log.info("IBM MQ Connection Factory configured - QueueManager: {}, Channel: {}, ConnName: {}", 
                    queueManager, channel, connName);
            
        } catch (JMSException e) {
            log.error("Failed to configure IBM MQ Connection Factory", e);
            throw new RuntimeException("MQ Configuration Error", e);
        }
        
        return factory;
    }
    
    /**
     * JMS Template for sending messages
     */
    @Bean
    public JmsTemplate jmsTemplate(ConnectionFactory connectionFactory) {
        JmsTemplate template = new JmsTemplate(connectionFactory);
        
        // Message conversion
        template.setMessageConverter(jacksonJmsMessageConverter());
        
        // Delivery options
        template.setDeliveryPersistent(true); // Ensure message persistence for clinical data
        template.setExplicitQosEnabled(true);
        template.setTimeToLive(86400000); // 24 hours TTL for clinical messages
        
        // Performance settings
        template.setSessionTransacted(true); // Enable transactions for reliability
        template.setSessionAcknowledgeMode(jakarta.jms.Session.AUTO_ACKNOWLEDGE);
        
        // Connection handling
        template.setConnectionFactory(connectionFactory);
        
        log.info("JMS Template configured with message persistence and 24h TTL");
        
        return template;
    }
    
    /**
     * JMS Listener Container Factory for consuming messages (if needed)
     */
    @Bean
    public DefaultJmsListenerContainerFactory jmsListenerContainerFactory(ConnectionFactory connectionFactory) {
        DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
        
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(jacksonJmsMessageConverter());
        
        // Concurrency settings for clinical data processing
        factory.setConcurrency("1-5"); // Start with 1, scale up to 5 consumers
        
        // Error handling
        factory.setErrorHandler(t -> {
            log.error("JMS Listener error in clinical data processing", t);
        });
        
        // Session management
        factory.setSessionTransacted(true);
        factory.setSessionAcknowledgeMode(jakarta.jms.Session.AUTO_ACKNOWLEDGE);
        
        // Recovery settings
        factory.setRecoveryInterval(30000); // 30 seconds
        factory.setMaxRecoveryTime(300000); // 5 minutes
        
        log.info("JMS Listener Container Factory configured for clinical data consumption");
        
        return factory;
    }
    
    /**
     * Message converter for JSON serialization/deserialization
     */
    @Bean
    public MessageConverter jacksonJmsMessageConverter() {
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter();
        
        // Use JSON for message format
        converter.setTargetType(MessageType.TEXT);
        converter.setTypeIdPropertyName("_messageType");
        
        // Configure for clinical data handling
        converter.setStrictContentTypeMatching(false);
        
        return converter;
    }
    
    /**
     * Health check bean for monitoring MQ connectivity
     */
    @Bean
    public MQHealthIndicator mqHealthIndicator(ConnectionFactory connectionFactory) {
        return new MQHealthIndicator(connectionFactory);
    }
    
    /**
     * Custom health indicator for IBM MQ
     */
    public static class MQHealthIndicator {
        private final ConnectionFactory connectionFactory;
        
        public MQHealthIndicator(ConnectionFactory connectionFactory) {
            this.connectionFactory = connectionFactory;
        }
        
        public boolean isHealthy() {
            try {
                // Attempt to create a connection to verify MQ availability
                var connection = connectionFactory.createConnection();
                connection.close();
                return true;
            } catch (Exception e) {
                log.warn("MQ Health check failed: {}", e.getMessage());
                return false;
            }
        }
        
        public String getStatus() {
            return isHealthy() ? "UP" : "DOWN";
        }
    }
}