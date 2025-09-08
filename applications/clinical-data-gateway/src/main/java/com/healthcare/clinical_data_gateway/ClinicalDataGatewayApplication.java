package com.healthcare.clinical_data_gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;


/**
 * Clinical Data Gateway Application
 * 
 * This Spring Boot application serves as the entry point for clinical trial data.
 * It receives REST API calls from clinical sites and forwards them to IBM MQ
 * for processing by downstream services.
 * 
 * Key Responsibilities:
 * - Receive clinical data via REST API
 * - Validate incoming data for HIPAA compliance
 * - Route messages to appropriate IBM MQ queues
 * - Provide audit trails for regulatory compliance
 * 
 * @author Healthcare Platform Demo
 * @version 1.0
 */
@SpringBootApplication
public class ClinicalDataGatewayApplication {

	public static void main(String[] args) {
		SpringApplication.run(ClinicalDataGatewayApplication.class, args);
	}

}
