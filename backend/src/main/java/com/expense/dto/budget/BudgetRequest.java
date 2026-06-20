package com.expense.dto.budget;

import com.expense.entity.enums.PeriodType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class BudgetRequest {

    @NotNull(message = "Limit amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    private BigDecimal amount;

    private LocalDate startDate;

    private LocalDate endDate;

    @NotNull(message = "Category is required")
    private Long categoryId;

    @Size(max = 255)
    private String note;

    private PeriodType periodType;

    @Min(1)
    @Max(100)
    private Integer warningThresholdPercent;

    private Boolean alertsEnabled;

    private Boolean isActive;
}
