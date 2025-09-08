package com.healthcare.clinical_data_gateway.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.jms.support.converter.MappingJackson2MessageConverter;
import org.springframework.jms.support.converter.MessageConverter;
import org.springframework.jms.support.converter.MessageType;

import jakarta.jms.ConnectionFactory;

/**
 * JMS Configuration for IBM MQ integration
 * Uses IBM MQ Spring Boot auto-configuration for connection factory
 */
@Configuration
@EnableJms
@Slf4j
public class JmsConfig {
    
    /**
     * JMS Template for sending messages
     * ConnectionFactory will be auto-configured by IBM MQ Spring Boot starter
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
        
        log.info("JMS Template configured with message persistence and 24h TTL");
        
        return template;
    }
    
    /**
     * JMS Listener Container Factory for consuming messages
     * ConnectionFactory will be auto-configured by IBM MQ Spring Boot starter
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
        factory.setRecoveryInterval(30000L); // 30 seconds
        
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
        
        log.info("Jackson JMS Message Converter configured for clinical data");
        
        return converter;
    }
}