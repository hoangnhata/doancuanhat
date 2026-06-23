package com.expense.dto.saving;

import com.expense.dto.transaction.TransactionDto;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingSpendResponse {

    private SavingGoalDto savingGoal;
    private TransactionDto transaction;
}
