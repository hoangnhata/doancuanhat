package com.expense.service;

import com.expense.dto.budget.CheckTransactionRequest;
import com.expense.entity.Budget;
import com.expense.entity.Category;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.entity.enums.PeriodType;
import com.expense.entity.enums.SpendingLimitStatus;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.BudgetRepository;
import com.expense.repository.TransactionRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BudgetServiceTest {

    @Mock private BudgetRepository budgetRepository;
    @Mock private TransactionRepository transactionRepository;
    @Mock private UserService userService;
    @Mock private CategoryService categoryService;

    @InjectMocks private BudgetService budgetService;

    @Test
    void computeStatus_safeWarningExceeded() {
        assertEquals(SpendingLimitStatus.SAFE, budgetService.computeStatus(new BigDecimal("50"), 80));
        assertEquals(SpendingLimitStatus.WARNING, budgetService.computeStatus(new BigDecimal("80"), 80));
        assertEquals(SpendingLimitStatus.EXCEEDED, budgetService.computeStatus(new BigDecimal("100"), 80));
    }

    @Test
    void checkTransaction_expenseExceededWarning() {
        User user = User.builder().id(1L).build();
        Category cat = Category.builder().id(5L).name("Ăn uống").type(CategoryType.EXPENSE).build();
        Budget budget = Budget.builder()
                .id(10L)
                .user(user)
                .category(cat)
                .amount(new BigDecimal("2000000"))
                .startDate(LocalDate.of(2026, 6, 1))
                .endDate(LocalDate.of(2026, 6, 30))
                .warningThresholdPercent(80)
                .alertsEnabled(true)
                .periodType(PeriodType.MONTHLY)
                .build();

        when(userService.getCurrentUserEntity()).thenReturn(user);
        when(budgetRepository.findActiveByUserIdAndCategoryIdAndDate(eq(1L), eq(5L), any()))
                .thenReturn(List.of(budget));
        when(transactionRepository.sumAmountByUserCategoryTypeAndDateRangeExcluding(
                eq(1L), eq(5L), eq(TransactionType.EXPENSE), any(), any(), isNull()))
                .thenReturn(new BigDecimal("1800000"));

        CheckTransactionRequest req = new CheckTransactionRequest();
        req.setCategoryId(5L);
        req.setAmount(new BigDecimal("300000"));
        req.setTransactionDate(LocalDate.of(2026, 6, 16));
        req.setType(TransactionType.EXPENSE);

        var res = budgetService.checkTransaction(req);
        assertTrue(res.isHasWarning());
        assertEquals(SpendingLimitStatus.EXCEEDED, res.getStatus());
        assertEquals(new BigDecimal("2100000"), res.getProjectedSpent());
    }

    @Test
    void checkTransaction_incomeNoWarning() {
        CheckTransactionRequest req = new CheckTransactionRequest();
        req.setCategoryId(5L);
        req.setAmount(new BigDecimal("5000000"));
        req.setTransactionDate(LocalDate.now());
        req.setType(TransactionType.INCOME);

        var res = budgetService.checkTransaction(req);
        assertFalse(res.isHasWarning());
    }
}
