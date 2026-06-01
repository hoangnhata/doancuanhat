package com.expense.dto.transaction;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AICategorizeBatchRequest {

    /** Raw input containing 1+ items, e.g. "ăn 30k, grab 45k, điện 50k" */
    @NotBlank(message = "Text input is required")
    private String text;

    /** Optional: HAPPY, SAD, ANGRY */
    private String personality;
}

