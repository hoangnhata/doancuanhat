package com.expense.dto.user;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class UserProfileRequest {

    @Size(min = 2, max = 100)
    private String fullName;

    @Size(max = 20)
    private String phone;

    @Pattern(regexp = "HAPPY|SAD|ANGRY", message = "Personality must be HAPPY, SAD, or ANGRY")
    private String botPersonality;

    private Boolean onboardingCompleted;

    @Size(max = 100)
    private String walletName;

    @Size(max = 10)
    private String currencyCode;

    private BigDecimal initialBalance;

    private BigDecimal savingsGoalMonthly;
}
