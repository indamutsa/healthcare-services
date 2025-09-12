package com.healthcare.lab_results_processor.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * Entity representing a processed lab result stored in the database
 */
@Entity
@Table(name = "processed_lab_results", indexes = {
    @Index(name = "idx_patient_id", columnList = "patientId"),
    @Index(name = "idx_test_type", columnList = "testType"),
    @Index(name = "idx_test_date", columnList = "testDate"),
    @Index(name = "idx_severity", columnList = "severityLevel"),
    @Index(name = "idx_abnormal", columnList = "isAbnormal")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProcessedLabResult {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String messageId;
    
    @Column(nullable = false)
    private String patientId;
    
    @Column(nullable = false)
    private String testType;
    
    @Column(nullable = false)
    private Double resultValue;
    
    @Column(nullable = false)
    private String unit;
    
    @Column(nullable = false)
    private String referenceRange;
    
    @Column(nullable = false)
    private String testDate;
    
    @Column(nullable = false)
    private String labTechnicianId;
    
    @Column(nullable = false)
    private Boolean isAbnormal;
    
    @Column(nullable = false)
    private String severityLevel;
    
    @Column(nullable = false)
    private String clinicalInterpretation;
    
    @Column(nullable = false)
    private Boolean requiresImmediateAttention;
    
    @Column(nullable = false)
    private String studyPhase;
    
    @Column(nullable = false)
    private String siteId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProcessingStatus processingStatus;
    
    @Column(length = 1000)
    private String processingNotes;
    
    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @UpdateTimestamp
    @Column(nullable = false)
    private LocalDateTime updatedAt;
    
    @Column(nullable = false)
    private LocalDateTime processedAt;
    
    public enum ProcessingStatus {
        RECEIVED,
        VALIDATED,
        PROCESSED,
        ALERT_SENT,
        COMPLETED,
        FAILED
    }
    
    /**
     * Check if this result is critical and needs immediate attention
     */
    public boolean isCritical() {
        return requiresImmediateAttention || "Severe".equals(severityLevel);
    }
    
    /**
     * Get a summary description of the result
     */
    public String getSummary() {
        return String.format("%s: %s %s (%s) - %s", 
            testType, resultValue, unit, severityLevel, clinicalInterpretation);
    }
}