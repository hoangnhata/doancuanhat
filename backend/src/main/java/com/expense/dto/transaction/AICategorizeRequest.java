package com.expense.dto.transaction;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AICategorizeRequest {

    @NotBlank(message = "Text input is required")
    private String text;

    private String personality; // HAPPY, SAD, ANGRY - optional, uses user's default if not set
}
