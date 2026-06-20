package com.expense.service;

import com.expense.entity.Wallet;
import com.expense.entity.enums.SavingTransactionType;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.SavingTransactionRepository;
import com.expense.repository.TransactionRepository;
import com.expense.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class WalletBalanceService {

    private final TransactionRepository transactionRepository;
    private final SavingTransactionRepository savingTransactionRepository;
    private final WalletRepository walletRepository;

    public BigDecimal getCurrentBalance(Long userId, Wallet wallet) {
        boolean includeLegacy = walletRepository.findByUserIdAndIsDefaultTrue(userId)
                .map(w -> w.getId().equals(wallet.getId()))
                .orElse(false);

        BigDecimal income = transactionRepository.sumAllAmountByUserWalletAndType(
                userId, wallet.getId(), TransactionType.INCOME, includeLegacy);
        BigDecimal expense = transactionRepository.sumAllAmountByUserWalletAndType(
                userId, wallet.getId(), TransactionType.EXPENSE, includeLegacy);
        BigDecimal deposits = savingTransactionRepository.sumAmountByWalletAndType(
                wallet.getId(), userId, SavingTransactionType.DEPOSIT);
        BigDecimal withdraws = savingTransactionRepository.sumAmountByWalletAndType(
                wallet.getId(), userId, SavingTransactionType.WITHDRAW);

        if (income == null) income = BigDecimal.ZERO;
        if (expense == null) expense = BigDecimal.ZERO;
        if (deposits == null) deposits = BigDecimal.ZERO;
        if (withdraws == null) withdraws = BigDecimal.ZERO;

        BigDecimal initial = wallet.getInitialBalance() != null ? wallet.getInitialBalance() : BigDecimal.ZERO;
        return initial.add(income).subtract(expense).subtract(deposits).add(withdraws);
    }
}
