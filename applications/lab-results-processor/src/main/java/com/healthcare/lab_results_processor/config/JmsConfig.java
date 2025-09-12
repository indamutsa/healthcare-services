package com.healthcare.lab_results_processor.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jms.annotation.EnableJms;
import org.springframework.jms.config.DefaultJmsListenerContainerFactory;
import org.springframework.jms.config.JmsListenerContainerFactory;

import jakarta.jms.ConnectionFactory;

/**
 * JMS Configuration for lab results processing
 */
@Configuration
@EnableJms
public class JmsConfig {
    
    /**
     * ObjectMapper for JSON processing
     */
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
    
    /**
     * JMS Listener Container Factory configuration
     */
    @Bean
    public JmsListenerContainerFactory<?> jmsListenerContainerFactory(ConnectionFactory connectionFactory) {
        DefaultJmsListenerContainerFactory factory = new DefaultJmsListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setConcurrency("3-10");
        factory.setSessionAcknowledgeMode(jakarta.jms.Session.AUTO_ACKNOWLEDGE);
        return factory;
    }
}