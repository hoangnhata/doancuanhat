package com.expense.dto.user;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OnboardingStatusDto {

    private Boolean walletSetupCompleted;
    private Boolean savingGoalSetupCompleted;
    private Boolean savingGoalSetupSkipped;
    private Boolean spendingLimitSetupCompleted;
    private Boolean spendingLimitSetupSkipped;
    private Boolean onboardingCompleted;
    private String onboardingStep;
}
