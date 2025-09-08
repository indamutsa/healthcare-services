package com.healthcare.clinical_data_gateway.exception;

/**
 * Custom exception for clinical data processing errors
 * Used to wrap and categorize clinical data specific errors
 */
public class ClinicalDataException extends RuntimeException {
    
    private final String errorCode;
    private final String patientId;
    private final String messageId;
    
    public ClinicalDataException(String message) {
        super(message);
        this.errorCode = "CLINICAL_DATA_ERROR";
        this.patientId = null;
        this.messageId = null;
    }
    
    public ClinicalDataException(String message, Throwable cause) {
        super(message, cause);
        this.errorCode = "CLINICAL_DATA_ERROR";
        this.patientId = null;
        this.messageId = null;
    }
    
    public ClinicalDataException(String message, String errorCode) {
        super(message);
        this.errorCode = errorCode;
        this.patientId = null;
        this.messageId = null;
    }
    
    public ClinicalDataException(String message, String errorCode, String patientId, String messageId) {
        super(message);
        this.errorCode = errorCode;
        this.patientId = patientId;
        this.messageId = messageId;
    }
    
    public ClinicalDataException(String message, String errorCode, String patientId, String messageId, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.patientId = patientId;
        this.messageId = messageId;
    }
    
    public String getErrorCode() {
        return errorCode;
    }
    
    public String getPatientId() {
        return patientId;
    }
    
    public String getMessageId() {
        return messageId;
    }
    
    /**
     * Check if this exception contains HIPAA sensitive information
     */
    public boolean containsSensitiveData() {
        return patientId != null;
    }
    
    /**
     * Get sanitized message for logging (removes sensitive data)
     */
    public String getSanitizedMessage() {
        String message = getMessage();
        if (patientId != null) {
            // Replace patient ID with masked version for logging
            message = message.replace(patientId, "PT******");
        }
        return message;
    }
}