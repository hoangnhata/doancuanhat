package com.expense.dto.transaction;

import com.expense.dto.category.CategoryDto;
import com.expense.dto.wallet.WalletDto;
import com.expense.entity.enums.TransactionType;
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
public class TransactionDto {

    private Long id;
    private TransactionType type;
    private BigDecimal amount;
    private String description;
    private LocalDate transactionDate;
    private CategoryDto category;
    private WalletDto wallet;
    private LocalDateTime createdAt;
}
