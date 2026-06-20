package com.expense.dto.saving;

import com.expense.entity.enums.SavingTransactionType;
import com.expense.dto.wallet.WalletDto;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingTransactionDto {

    private Long id;
    private Long savingGoalId;
    private WalletDto wallet;
    private BigDecimal amount;
    private SavingTransactionType type;
    private String note;
    private LocalDateTime createdAt;
}
