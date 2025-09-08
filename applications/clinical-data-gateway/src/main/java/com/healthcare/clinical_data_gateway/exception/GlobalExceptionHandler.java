package com.healthcare.clinical_data_gateway.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Global exception handler for clinical data gateway
 * Provides consistent error responses and proper logging while protecting HIPAA data
 */
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {
    
    /**
     * Handle clinical data specific exceptions
     */
    @ExceptionHandler(ClinicalDataException.class)
    public ResponseEntity<Map<String, Object>> handleClinicalDataException(
            ClinicalDataException ex, WebRequest request) {
        
        // Use sanitized message for logging to protect HIPAA data
        log.error("Clinical data processing error: {} - Code: {}", 
                ex.getSanitizedMessage(), ex.getErrorCode(), ex);
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "CLINICAL_DATA_ERROR",
                ex.getMessage(),
                HttpStatus.BAD_REQUEST
        );
        
        // Add clinical-specific error details
        errorResponse.put("errorCode", ex.getErrorCode());
        if (ex.getMessageId() != null) {
            errorResponse.put("messageId", ex.getMessageId());
        }
        
        // Never include patient ID in response for HIPAA compliance
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    /**
     * Handle validation errors from @Valid annotations
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationErrors(
            MethodArgumentNotValidException ex, WebRequest request) {
        
        log.warn("Validation error in clinical data request: {}", ex.getMessage());
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "VALIDATION_ERROR",
                "Clinical data validation failed",
                HttpStatus.BAD_REQUEST
        );
        
        // Collect all field validation errors
        Map<String, String> fieldErrors = new HashMap<>();
        ex.getBindingResult().getAllErrors().forEach(error -> {
            if (error instanceof FieldError fieldError) {
                fieldErrors.put(fieldError.getField(), fieldError.getDefaultMessage());
            } else {
                fieldErrors.put("global", error.getDefaultMessage());
            }
        });
        
        errorResponse.put("validationErrors", fieldErrors);
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    /**
     * Handle constraint violation exceptions
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraintViolationException(
            ConstraintViolationException ex, WebRequest request) {
        
        log.warn("Constraint violation in clinical data: {}", ex.getMessage());
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "CONSTRAINT_VIOLATION",
                "Clinical data constraint validation failed",
                HttpStatus.BAD_REQUEST
        );
        
        Set<ConstraintViolation<?>> violations = ex.getConstraintViolations();
        Map<String, String> violationErrors = violations.stream()
                .collect(Collectors.toMap(
                        violation -> violation.getPropertyPath().toString(),
                        ConstraintViolation::getMessage,
                        (existing, replacement) -> existing + "; " + replacement
                ));
        
        errorResponse.put("constraintViolations", violationErrors);
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    /**
     * Handle JMS/messaging related exceptions
     */
    @ExceptionHandler(org.springframework.jms.JmsException.class)
    public ResponseEntity<Map<String, Object>> handleJmsException(
            org.springframework.jms.JmsException ex, WebRequest request) {
        
        log.error("JMS error in clinical data processing: {}", ex.getMessage(), ex);
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "MESSAGING_ERROR",
                "Clinical data messaging system unavailable",
                HttpStatus.SERVICE_UNAVAILABLE
        );
        
        errorResponse.put("retryable", true);
        errorResponse.put("retryAfter", 30); // Suggest retry after 30 seconds
        
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(errorResponse);
    }
    
    /**
     * Handle JSON processing errors
     */
    @ExceptionHandler(com.fasterxml.jackson.core.JsonProcessingException.class)
    public ResponseEntity<Map<String, Object>> handleJsonProcessingException(
            com.fasterxml.jackson.core.JsonProcessingException ex, WebRequest request) {
        
        log.error("JSON processing error in clinical data: {}", ex.getMessage());
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "JSON_PROCESSING_ERROR",
                "Invalid clinical data format",
                HttpStatus.BAD_REQUEST
        );
        
        errorResponse.put("hint", "Please verify JSON structure and data types");
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    /**
     * Handle illegal argument exceptions
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgumentException(
            IllegalArgumentException ex, WebRequest request) {
        
        log.warn("Illegal argument in clinical data processing: {}", ex.getMessage());
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "INVALID_ARGUMENT",
                "Invalid clinical data parameter: " + ex.getMessage(),
                HttpStatus.BAD_REQUEST
        );
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    /**
     * Handle all other unexpected exceptions
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(
            Exception ex, WebRequest request) {
        
        // Log with full stack trace for debugging, but don't expose details to client
        log.error("Unexpected error in clinical data processing", ex);
        
        Map<String, Object> errorResponse = createBaseErrorResponse(
                "INTERNAL_ERROR",
                "An unexpected error occurred processing clinical data",
                HttpStatus.INTERNAL_SERVER_ERROR
        );
        
        // In development, you might want to include more details
        // errorResponse.put("debugMessage", ex.getMessage());
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Create base error response structure
     */
    private Map<String, Object> createBaseErrorResponse(String errorType, String message, HttpStatus status) {
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", errorType);
        errorResponse.put("message", message);
        errorResponse.put("status", status.value());
        errorResponse.put("timestamp", LocalDateTime.now());
        errorResponse.put("service", "clinical-data-gateway");
        
        return errorResponse;
    }
}