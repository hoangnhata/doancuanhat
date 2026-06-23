package com.expense.dto.saving;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class SavingSpendRequest {

    @NotNull(message = "Category is required")
    private Long categoryId;

    @NotNull(message = "Wallet is required")
    private Long walletId;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    private BigDecimal amount;

    @Size(max = 500)
    private String description;

    @NotNull(message = "Transaction date is required")
    private LocalDate transactionDate;
}
