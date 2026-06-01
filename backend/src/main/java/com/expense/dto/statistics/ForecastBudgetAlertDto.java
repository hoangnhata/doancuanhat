package com.expense.dto.statistics;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ForecastBudgetAlertDto {

    private String categoryName;
    private long budgetAmountVnd;
    private long spentVnd;
    private long remainingVnd;
    /** 0–100+ (có thể >100 nếu vượt) */
    private int percentUsed;
    /** OVER | WARN | OK */
    private String severity;
}
