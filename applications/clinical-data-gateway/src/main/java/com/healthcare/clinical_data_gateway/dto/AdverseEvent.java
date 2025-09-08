import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import javax.validation.constraints.*;

/**
 * Adverse event report
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class AdverseEvent {
    
    @NotBlank(message = "Patient ID is required")
    @JsonProperty("patient_id")
    private String patientId;
    
    @NotBlank(message = "Event description is required")
    @JsonProperty("event_description")
    private String eventDescription;
    
    @NotBlank(message = "Severity is required")
    @Pattern(regexp = "Mild|Moderate|Severe", message = "Severity must be Mild, Moderate, or Severe")
    @JsonProperty("severity")
    private String severity;
    
    @NotBlank(message = "Start date is required")
    @JsonProperty("start_date")
    private String startDate;
    
    @JsonProperty("end_date")
    private String endDate; // Optional - event may be ongoing
    
    @NotNull(message = "Study drug relation flag is required")
    @JsonProperty("related_to_study_drug")
    private Boolean relatedToStudyDrug;
    
    @NotBlank(message = "Action taken is required")
    @JsonProperty("action_taken")
    private String actionTaken;
}