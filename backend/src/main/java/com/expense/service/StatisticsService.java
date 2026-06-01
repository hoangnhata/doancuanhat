package com.expense.service;

import com.expense.dto.statistics.DailyBreakdownResponse;
import com.expense.dto.statistics.StatisticsResponse;
import com.expense.entity.User;
import com.expense.entity.enums.TransactionType;
import com.expense.repository.CategoryRepository;
import com.expense.repository.TransactionRepository;
import com.expense.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class StatisticsService {

    private static final Logger log = LoggerFactory.getLogger(StatisticsService.class);

    private final TransactionRepository transactionRepository;
    private final CategoryRepository categoryRepository;
    private final WalletRepository walletRepository;
    private final UserService userService;

    public StatisticsResponse getStatisticsByDay(LocalDate date, Long walletId) {
        User user = userService.getCurrentUserEntity();
        LocalDate targetDate = date != null ? date : LocalDate.now();
        return getStatistics(user.getId(), targetDate, targetDate, TransactionType.EXPENSE, walletId);
    }

    public StatisticsResponse getStatisticsByMonth(int year, int month, TransactionType categoryType, Long walletId) {
        User user = userService.getCurrentUserEntity();
        LocalDate startDate = LocalDate.of(year, month, 1);
        LocalDate endDate = startDate.withDayOfMonth(startDate.lengthOfMonth());
        return getStatistics(user.getId(), startDate, endDate, categoryType != null ? categoryType : TransactionType.EXPENSE, walletId);
    }

    public StatisticsResponse getStatisticsByYear(int year, TransactionType categoryType, Long walletId) {
        User user = userService.getCurrentUserEntity();
        LocalDate startDate = LocalDate.of(year, 1, 1);
        LocalDate endDate = LocalDate.of(year, 12, 31);
        return getStatistics(user.getId(), startDate, endDate, categoryType != null ? categoryType : TransactionType.EXPENSE, walletId);
    }

    public StatisticsResponse getStatisticsByDateRange(LocalDate startDate, LocalDate endDate, TransactionType categoryType, Long walletId) {
        User user = userService.getCurrentUserEntity();
        if (startDate == null) startDate = LocalDate.now().minusMonths(1);
        if (endDate == null) endDate = LocalDate.now();
        return getStatistics(user.getId(), startDate, endDate, categoryType != null ? categoryType : TransactionType.EXPENSE, walletId);
    }

    public DailyBreakdownResponse getDailyBreakdown(LocalDate startDate, LocalDate endDate) {
        User user = userService.getCurrentUserEntity();
        if (startDate == null) startDate = LocalDate.now().minusMonths(1);
        if (endDate == null) endDate = LocalDate.now();
        if (startDate.isAfter(endDate)) {
            LocalDate tmp = startDate;
            startDate = endDate;
            endDate = tmp;
        }
        List<Object[]> raw = transactionRepository.sumAmountByDateAndType(user.getId(), startDate, endDate);
        Map<LocalDate, DailyBreakdownResponse.DaySummary> map = new LinkedHashMap<>();
        for (Object[] row : raw) {
            LocalDate d = (LocalDate) row[0];
            TransactionType type = (TransactionType) row[1];
            BigDecimal amount = (BigDecimal) row[2];
            if (amount == null) amount = BigDecimal.ZERO;
            map.computeIfAbsent(d, k -> DailyBreakdownResponse.DaySummary.builder()
                    .date(k)
                    .income(BigDecimal.ZERO)
                    .expense(BigDecimal.ZERO)
                    .build());
            DailyBreakdownResponse.DaySummary day = map.get(d);
            if (type == TransactionType.INCOME) {
                day.setIncome(amount);
            } else {
                day.setExpense(amount);
            }
        }
        List<DailyBreakdownResponse.DaySummary> days = new ArrayList<>();
        for (LocalDate d = startDate; !d.isAfter(endDate); d = d.plusDays(1)) {
            days.add(map.getOrDefault(d, DailyBreakdownResponse.DaySummary.builder()
                    .date(d)
                    .income(BigDecimal.ZERO)
                    .expense(BigDecimal.ZERO)
                    .build()));
        }
        return DailyBreakdownResponse.builder().days(days).build();
    }

    private StatisticsResponse getStatistics(Long userId, LocalDate startDate, LocalDate endDate, TransactionType categoryType, Long walletId) {
        BigDecimal totalIncome;
        BigDecimal totalExpense;
        List<Object[]> categorySums;

        if (walletId == null) {
            totalIncome = transactionRepository.sumAmountByUserIdAndTypeAndDateRange(
                    userId, TransactionType.INCOME, startDate, endDate);
            totalExpense = transactionRepository.sumAmountByUserIdAndTypeAndDateRange(
                    userId, TransactionType.EXPENSE, startDate, endDate);
            categorySums = transactionRepository.sumAmountByCategoryAndDateRange(
                    userId, categoryType, startDate, endDate);
        } else {
            boolean includeLegacy = walletRepository.findByUserIdAndIsDefaultTrue(userId)
                    .map(w -> w.getId().equals(walletId))
                    .orElse(false);
            totalIncome = transactionRepository.sumAmountByUserIdAndTypeAndDateRangeWithWallet(
                    userId, TransactionType.INCOME, startDate, endDate, walletId, includeLegacy);
            totalExpense = transactionRepository.sumAmountByUserIdAndTypeAndDateRangeWithWallet(
                    userId, TransactionType.EXPENSE, startDate, endDate, walletId, includeLegacy);
            categorySums = transactionRepository.sumAmountByCategoryAndDateRangeWithWallet(
                    userId, categoryType, startDate, endDate, walletId, includeLegacy);
        }

        if (totalIncome == null) totalIncome = BigDecimal.ZERO;
        if (totalExpense == null) totalExpense = BigDecimal.ZERO;

        BigDecimal balance = totalIncome.subtract(totalExpense);

        List<StatisticsResponse.CategorySummary> byCategory = categorySums.stream()
                .map(row -> {
                    Long categoryId = (Long) row[0];
                    BigDecimal amount = (BigDecimal) row[1];
                    String categoryName = categoryRepository.findById(categoryId)
                            .map(c -> c.getName())
                            .orElse("Unknown");
                    return StatisticsResponse.CategorySummary.builder()
                            .categoryId(categoryId)
                            .categoryName(categoryName)
                            .amount(amount)
                            .build();
                })
                .collect(Collectors.toList());

        return StatisticsResponse.builder()
                .totalIncome(totalIncome)
                .totalExpense(totalExpense)
                .balance(balance)
                .byCategory(byCategory)
                .build();
    }
}
