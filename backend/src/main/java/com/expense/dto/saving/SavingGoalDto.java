package com.expense.dto.saving;

import com.expense.entity.enums.SavingGoalStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingGoalDto {

    private Long id;
    private String name;
    private BigDecimal targetAmount;
    private BigDecimal currentAmount;
    private LocalDate targetDate;
    private SavingGoalStatus status;
    private String note;
    private BigDecimal remainingAmount;
    private BigDecimal progressPercent;
    private Boolean isCompleted;
    private LocalDateTime completedAt;
    private Long durationDays;
    private BigDecimal totalSavedAmount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
