package com.expense.dto.user;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserDto {

    private Long id;
    private String fullName;
    private String email;
    private String phone;
    private String botPersonality;
    private Boolean onboardingCompleted;
    private String walletName;
    private String currencyCode;
    private java.math.BigDecimal initialBalance;
    private java.math.BigDecimal savingsGoalMonthly;
    private LocalDateTime createdAt;
}
