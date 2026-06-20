package com.expense.service;

import com.expense.dto.saving.SavingGoalRequest;
import com.expense.dto.saving.SavingTransferRequest;
import com.expense.entity.SavingGoal;
import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.entity.enums.SavingGoalStatus;
import com.expense.entity.enums.SavingTransactionType;
import com.expense.repository.SavingGoalRepository;
import com.expense.repository.SavingTransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SavingGoalServiceTest {

    @Mock private SavingGoalRepository savingGoalRepository;
    @Mock private SavingTransactionRepository savingTransactionRepository;
    @Mock private UserService userService;
    @Mock private WalletService walletService;
    @Mock private WalletBalanceService walletBalanceService;

    @InjectMocks private SavingGoalService savingGoalService;

    private User user;
    private Wallet wallet;
    private SavingGoal goal;

    @BeforeEach
    void setUp() {
        user = User.builder().id(1L).email("test@test.com").build();
        wallet = Wallet.builder().id(10L).user(user).initialBalance(new BigDecimal("5000000")).name("Ví chính").build();
        goal = SavingGoal.builder()
                .id(100L)
                .user(user)
                .name("Mua xe")
                .targetAmount(new BigDecimal("15000000"))
                .currentAmount(BigDecimal.ZERO)
                .status(SavingGoalStatus.ACTIVE)
                .build();
    }

    @Test
    void deposit_reducesWalletBalanceConceptually_andIncreasesGoal() {
        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(savingGoalRepository.findByUserIdAndId(1L, 100L)).thenReturn(Optional.of(goal));
        when(walletService.getWalletEntity(10L, 1L)).thenReturn(wallet);
        when(walletBalanceService.getCurrentBalance(1L, wallet)).thenReturn(new BigDecimal("5000000"));
        when(savingGoalRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(savingTransactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SavingTransferRequest request = new SavingTransferRequest();
        request.setWalletId(10L);
        request.setAmount(new BigDecimal("1000000"));

        var result = savingGoalService.deposit(100L, request);

        assertEquals(new BigDecimal("1000000"), result.getCurrentAmount());
        assertEquals(SavingGoalStatus.ACTIVE, result.getStatus());

        ArgumentCaptor<com.expense.entity.SavingTransaction> txCaptor =
                ArgumentCaptor.forClass(com.expense.entity.SavingTransaction.class);
        verify(savingTransactionRepository).save(txCaptor.capture());
        assertEquals(SavingTransactionType.DEPOSIT, txCaptor.getValue().getType());
    }

    @Test
    void withdraw_returnsMoneyToWallet_andDecreasesGoal() {
        goal.setCurrentAmount(new BigDecimal("1000000"));
        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(savingGoalRepository.findByUserIdAndId(1L, 100L)).thenReturn(Optional.of(goal));
        when(walletService.getWalletEntity(10L, 1L)).thenReturn(wallet);
        when(savingGoalRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(savingTransactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SavingTransferRequest request = new SavingTransferRequest();
        request.setWalletId(10L);
        request.setAmount(new BigDecimal("300000"));

        var result = savingGoalService.withdraw(100L, request);

        assertEquals(new BigDecimal("700000"), result.getCurrentAmount());
        verify(savingTransactionRepository).save(argThat(tx ->
                tx.getType() == SavingTransactionType.WITHDRAW && tx.getAmount().compareTo(new BigDecimal("300000")) == 0));
    }

    @Test
    void deposit_untilTarget_setsCompletedStatus() {
        goal.setCurrentAmount(new BigDecimal("14000000"));
        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(savingGoalRepository.findByUserIdAndId(1L, 100L)).thenReturn(Optional.of(goal));
        when(walletService.getWalletEntity(10L, 1L)).thenReturn(wallet);
        when(walletBalanceService.getCurrentBalance(1L, wallet)).thenReturn(new BigDecimal("5000000"));
        when(savingGoalRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(savingTransactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SavingTransferRequest request = new SavingTransferRequest();
        request.setWalletId(10L);
        request.setAmount(new BigDecimal("1000000"));

        var result = savingGoalService.deposit(100L, request);

        assertEquals(SavingGoalStatus.COMPLETED, result.getStatus());
        assertTrue(result.getIsCompleted());
    }

    @Test
    void withdraw_belowTarget_reactivatesGoal() {
        goal.setCurrentAmount(new BigDecimal("15000000"));
        goal.setStatus(SavingGoalStatus.COMPLETED);
        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(savingGoalRepository.findByUserIdAndId(1L, 100L)).thenReturn(Optional.of(goal));
        when(walletService.getWalletEntity(10L, 1L)).thenReturn(wallet);
        when(savingGoalRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(savingTransactionRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SavingTransferRequest request = new SavingTransferRequest();
        request.setWalletId(10L);
        request.setAmount(new BigDecimal("500000"));

        var result = savingGoalService.withdraw(100L, request);

        assertEquals(SavingGoalStatus.ACTIVE, result.getStatus());
        assertFalse(result.getIsCompleted());
    }

    @Test
    void create_withInitialAmount_doesNotCreateTransaction() {
        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(savingGoalRepository.save(any())).thenAnswer(inv -> {
            SavingGoal g = inv.getArgument(0);
            g.setId(1L);
            return g;
        });

        SavingGoalRequest request = new SavingGoalRequest();
        request.setName("Du lịch");
        request.setTargetAmount(new BigDecimal("15000000"));
        request.setInitialAmount(new BigDecimal("500000"));

        var result = savingGoalService.create(request);

        assertEquals(new BigDecimal("500000"), result.getCurrentAmount());
        verifyNoInteractions(savingTransactionRepository);
    }
}
