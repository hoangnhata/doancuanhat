package com.expense.dto.budget;

import com.expense.entity.enums.TransactionType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class CheckTransactionRequest {

    @NotNull
    private Long categoryId;

    @NotNull
    @DecimalMin(value = "0.01")
    private BigDecimal amount;

    @NotNull
    private LocalDate transactionDate;

    @NotNull
    private TransactionType type;

    /** Khi sửa giao dịch, loại trừ chính giao dịch đó khỏi tổng đã chi */
    private Long excludeTransactionId;
}
