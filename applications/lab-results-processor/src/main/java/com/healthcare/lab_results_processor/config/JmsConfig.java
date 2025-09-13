package com.healthcare.lab_results_processor.config;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.support.converter.MappingJackson2MessageConverter;
import org.springframework.jms.support.converter.MessageConverter;
import org.springframework.jms.support.converter.MessageType;

import jakarta.jms.ConnectionFactory;

/**
 * JMS Configuration for lab results processing
 */
@Configuration
@EnableJms
@Slf4j
public class JmsConfig {
    
    /**
     * ObjectMapper for JSON processing
     */
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // Support Java time types and human-readable dates
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        // Be tolerant to extra/computed properties from the gateway DTOs
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        return mapper;
    }
    
    /**
     * JMS Listener Container Factory for consuming messages
     */
    @Bean
    public DefaultJmsListenerContainerFactory jmsListenerContainerFactory(ConnectionFactory connectionFactory) {
        DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
        
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(jacksonJmsMessageConverter());
        
        // Concurrency settings for lab results processing
        factory.setConcurrency("1-5"); // Start with 1, scale up to 5 consumers
        
        // Error handling
        factory.setErrorHandler(t -> {
            log.error("JMS Listener error in lab results processing", t);
        });
        
        // Session management
        factory.setSessionTransacted(true);
        factory.setSessionAcknowledgeMode(jakarta.jms.Session.AUTO_ACKNOWLEDGE);
        
        // Recovery settings
        factory.setRecoveryInterval(30000L); // 30 seconds
        
        log.info("JMS Listener Container Factory configured for lab results consumption");
        
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
        
        log.info("Jackson JMS Message Converter configured for lab results");
        
        return converter;
    }
}
