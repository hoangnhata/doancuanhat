package com.expense.dto.budget;

import com.expense.entity.enums.SpendingLimitStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CheckTransactionResponse {

    private boolean hasWarning;
    private SpendingLimitStatus status;
    private String message;
    private BigDecimal currentSpent;
    private BigDecimal projectedSpent;
    private BigDecimal limitAmount;
    private BigDecimal projectedUsagePercent;
    private String categoryName;
}
