package com.healthcare.lab_results_processor.repository;

import com.healthcare.lab_results_processor.entity.ProcessedLabResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Repository for ProcessedLabResult entities
 */
@Repository
public interface ProcessedLabResultRepository extends JpaRepository<ProcessedLabResult, Long> {
    
    /**
     * Find lab result by message ID
     */
    Optional<ProcessedLabResult> findByMessageId(String messageId);
    
    /**
     * Find all lab results for a specific patient
     */
    List<ProcessedLabResult> findByPatientIdOrderByCreatedAtDesc(String patientId);
    
    /**
     * Find all abnormal lab results
     */
    List<ProcessedLabResult> findByIsAbnormalTrueOrderByCreatedAtDesc();
    
    /**
     * Find all lab results requiring immediate attention
     */
    List<ProcessedLabResult> findByRequiresImmediateAttentionTrueOrderByCreatedAtDesc();
    
    /**
     * Find lab results by test type
     */
    List<ProcessedLabResult> findByTestTypeOrderByCreatedAtDesc(String testType);
    
    /**
     * Find lab results by severity level
     */
    List<ProcessedLabResult> findBySeverityLevelOrderByCreatedAtDesc(String severityLevel);
    
    /**
     * Find lab results by processing status
     */
    List<ProcessedLabResult> findByProcessingStatusOrderByCreatedAtDesc(ProcessedLabResult.ProcessingStatus status);
    
    /**
     * Find recent lab results (within last N hours)
     */
    @Query("SELECT p FROM ProcessedLabResult p WHERE p.createdAt >= :since ORDER BY p.createdAt DESC")
    List<ProcessedLabResult> findRecentResults(@Param("since") LocalDateTime since);
    
    /**
     * Find critical lab results for a patient
     */
    @Query("SELECT p FROM ProcessedLabResult p WHERE p.patientId = :patientId AND " +
           "(p.requiresImmediateAttention = true OR p.severityLevel = 'Severe') " +
           "ORDER BY p.createdAt DESC")
    List<ProcessedLabResult> findCriticalResultsForPatient(@Param("patientId") String patientId);
    
    /**
     * Count results by severity level
     */
    @Query("SELECT p.severityLevel, COUNT(p) FROM ProcessedLabResult p GROUP BY p.severityLevel")
    List<Object[]> countBySeverityLevel();
    
    /**
     * Count results by test type
     */
    @Query("SELECT p.testType, COUNT(p) FROM ProcessedLabResult p GROUP BY p.testType")
    List<Object[]> countByTestType();
    
    /**
     * Check if a message has already been processed
     */
    boolean existsByMessageId(String messageId);
}