package com.expense.dto.recurring;

import com.expense.entity.enums.TransactionType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class RecurringTransactionRequest {

    @NotNull
    private TransactionType type;

    @NotNull
    @DecimalMin(value = "0.01")
    private BigDecimal amount;

    @Size(max = 500)
    private String description;

    @NotNull
    @Min(1)
    @Max(28)
    private Integer dayOfMonth;

    @NotNull
    private LocalDate startDate;

    private LocalDate endDate;

    @NotNull
    private Long categoryId;
}
