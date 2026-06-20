package com.expense.service;

import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.entity.enums.SavingTransactionType;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.SavingTransactionRepository;
import com.expense.repository.TransactionRepository;
import com.expense.repository.WalletRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WalletBalanceServiceTest {

    @Mock private TransactionRepository transactionRepository;
    @Mock private SavingTransactionRepository savingTransactionRepository;
    @Mock private WalletRepository walletRepository;

    @InjectMocks private WalletBalanceService walletBalanceService;

    private User user;
    private Wallet wallet;

    @BeforeEach
    void setUp() {
        user = User.builder().id(1L).build();
        wallet = Wallet.builder().id(10L).user(user).initialBalance(new BigDecimal("5000000")).isDefault(true).build();
    }

    @Test
    void balance_afterDepositAndWithdraw() {
        when(walletRepository.findByUserIdAndIsDefaultTrue(1L)).thenReturn(Optional.of(wallet));
        when(transactionRepository.sumAllAmountByUserWalletAndType(1L, 10L, TransactionType.INCOME, true))
                .thenReturn(BigDecimal.ZERO);
        when(transactionRepository.sumAllAmountByUserWalletAndType(1L, 10L, TransactionType.EXPENSE, true))
                .thenReturn(BigDecimal.ZERO);
        when(savingTransactionRepository.sumAmountByWalletAndType(10L, 1L, SavingTransactionType.DEPOSIT))
                .thenReturn(new BigDecimal("1000000"));
        when(savingTransactionRepository.sumAmountByWalletAndType(10L, 1L, SavingTransactionType.WITHDRAW))
                .thenReturn(new BigDecimal("300000"));

        BigDecimal balance = walletBalanceService.getCurrentBalance(1L, wallet);

        // 5M - 1M deposit + 300K withdraw = 4.3M
        assertEquals(new BigDecimal("4300000"), balance);
    }
}
