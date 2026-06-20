package com.expense.service;

import com.expense.dto.budget.*;
import com.expense.dto.category.CategoryDto;
import com.expense.dto.common.PageResponse;
import com.expense.entity.Budget;
import com.expense.entity.Category;
import com.expense.entity.User;
import com.expense.entity.enums.CategoryType;
import com.expense.entity.enums.PeriodType;
import com.expense.entity.enums.SpendingLimitStatus;
import com.expense.entity.enums.TransactionType;
import com.expense.exception.BadRequestException;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.BudgetRepository;
import com.expense.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.NumberFormat;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BudgetService {

    private static final Logger log = LoggerFactory.getLogger(BudgetService.class);
    private static final NumberFormat VND = NumberFormat.getNumberInstance(new Locale("vi", "VN"));

    private final BudgetRepository budgetRepository;
    private final TransactionRepository transactionRepository;
    private final UserService userService;
    private final CategoryService categoryService;

    @Transactional
    public BudgetDto create(BudgetRequest request) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());
        if (category.getType() != CategoryType.EXPENSE) {
            throw new BadRequestException("Hạn mức chi tiêu chỉ áp dụng cho danh mục chi tiêu");
        }

        PeriodType periodType = request.getPeriodType() != null ? request.getPeriodType() : PeriodType.MONTHLY;
        LocalDate[] range = resolvePeriodDates(periodType, request.getStartDate(), request.getEndDate(), LocalDate.now());
        validateDateRange(range[0], range[1]);

        Budget budget = Budget.builder()
                .amount(request.getAmount())
                .startDate(range[0])
                .endDate(range[1])
                .category(category)
                .user(user)
                .note(request.getNote())
                .periodType(periodType)
                .warningThresholdPercent(request.getWarningThresholdPercent() != null
                        ? request.getWarningThresholdPercent() : 80)
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .alertsEnabled(request.getAlertsEnabled() != null ? request.getAlertsEnabled() : true)
                .build();

        budget = budgetRepository.save(budget);
        log.info("Spending limit created: {} for user {}", budget.getId(), user.getId());
        return mapToDto(budget, user.getId(), null);
    }

    @Transactional(readOnly = true)
    public BudgetDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        Budget budget = getOwnedBudget(id, user.getId());
        return mapToDto(budget, user.getId(), null);
    }

    @Transactional(readOnly = true)
    public PageResponse<BudgetDto> getAll(Pageable pageable) {
        User user = userService.getCurrentUserEntity();
        Page<Budget> page = budgetRepository.findByUserId(user.getId(), pageable);
        return PageResponse.<BudgetDto>builder()
                .content(page.getContent().stream()
                        .map(b -> mapToDto(b, user.getId(), null))
                        .collect(Collectors.toList()))
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .build();
    }

    @Transactional(readOnly = true)
    public List<BudgetDto> getActiveBudgets(LocalDate date) {
        User user = userService.getCurrentUserEntity();
        LocalDate targetDate = date != null ? date : LocalDate.now();
        return budgetRepository.findActiveBudgetsByUserIdAndDate(user.getId(), targetDate).stream()
                .map(b -> mapToDto(b, user.getId(), null))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<SpendingLimitAlertDto> getAlerts(LocalDate date) {
        User user = userService.getCurrentUserEntity();
        LocalDate targetDate = date != null ? date : LocalDate.now();
        List<SpendingLimitAlertDto> alerts = new ArrayList<>();
        for (Budget budget : budgetRepository.findActiveBudgetsByUserIdAndDate(user.getId(), targetDate)) {
            if (Boolean.FALSE.equals(budget.getAlertsEnabled())) continue;
            BudgetDto dto = mapToDto(budget, user.getId(), null);
            if (dto.getStatus() == SpendingLimitStatus.WARNING || dto.getStatus() == SpendingLimitStatus.EXCEEDED) {
                alerts.add(toAlertDto(budget, dto));
            }
        }
        return alerts;
    }

    @Transactional(readOnly = true)
    public CheckTransactionResponse checkTransaction(CheckTransactionRequest request) {
        if (request.getType() != TransactionType.EXPENSE) {
            return CheckTransactionResponse.builder()
                    .hasWarning(false)
                    .status(SpendingLimitStatus.SAFE)
                    .message(null)
                    .build();
        }

        User user = userService.getCurrentUserEntity();
        List<Budget> limits = budgetRepository.findActiveByUserIdAndCategoryIdAndDate(
                user.getId(), request.getCategoryId(), request.getTransactionDate());

        if (limits.isEmpty()) {
            return CheckTransactionResponse.builder().hasWarning(false).build();
        }

        Budget budget = limits.get(0);
        if (Boolean.FALSE.equals(budget.getAlertsEnabled())) {
            return CheckTransactionResponse.builder().hasWarning(false).build();
        }

        BigDecimal currentSpent = sumSpent(user.getId(), budget, request.getExcludeTransactionId());
        BigDecimal projectedSpent = currentSpent.add(request.getAmount());
        int threshold = budget.getWarningThresholdPercent() != null ? budget.getWarningThresholdPercent() : 80;

        BigDecimal usagePercent = computeUsagePercent(projectedSpent, budget.getAmount());
        SpendingLimitStatus status = computeStatus(usagePercent, threshold);
        String categoryName = budget.getCategory().getName();

        if (status == SpendingLimitStatus.SAFE) {
            return CheckTransactionResponse.builder()
                    .hasWarning(false)
                    .status(SpendingLimitStatus.SAFE)
                    .currentSpent(currentSpent)
                    .projectedSpent(projectedSpent)
                    .limitAmount(budget.getAmount())
                    .projectedUsagePercent(usagePercent)
                    .categoryName(categoryName)
                    .build();
        }

        String message = buildProjectedMessage(categoryName, budget.getAmount(), projectedSpent, usagePercent, threshold, status);
        return CheckTransactionResponse.builder()
                .hasWarning(true)
                .status(status)
                .message(message)
                .currentSpent(currentSpent)
                .projectedSpent(projectedSpent)
                .limitAmount(budget.getAmount())
                .projectedUsagePercent(usagePercent)
                .categoryName(categoryName)
                .build();
    }

    @Transactional
    public BudgetDto update(Long id, BudgetRequest request) {
        User user = userService.getCurrentUserEntity();
        Budget budget = getOwnedBudget(id, user.getId());

        PeriodType periodType = request.getPeriodType() != null ? request.getPeriodType() : budget.getPeriodType();
        LocalDate[] range = resolvePeriodDates(
                periodType,
                request.getStartDate() != null ? request.getStartDate() : budget.getStartDate(),
                request.getEndDate() != null ? request.getEndDate() : budget.getEndDate(),
                budget.getStartDate());
        validateDateRange(range[0], range[1]);

        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());
        budget.setAmount(request.getAmount());
        budget.setStartDate(range[0]);
        budget.setEndDate(range[1]);
        budget.setCategory(category);
        budget.setNote(request.getNote());
        budget.setPeriodType(periodType);
        if (request.getWarningThresholdPercent() != null) {
            budget.setWarningThresholdPercent(request.getWarningThresholdPercent());
        }
        if (request.getAlertsEnabled() != null) budget.setAlertsEnabled(request.getAlertsEnabled());
        if (request.getIsActive() != null) budget.setIsActive(request.getIsActive());

        budget = budgetRepository.save(budget);
        log.info("Spending limit updated: {}", budget.getId());
        return mapToDto(budget, user.getId(), null);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        Budget budget = getOwnedBudget(id, user.getId());
        budget.setIsActive(false);
        budgetRepository.save(budget);
        log.info("Spending limit deactivated: {}", id);
    }

    private Budget getOwnedBudget(Long id, Long userId) {
        Budget budget = budgetRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("SpendingLimit", "id", id));
        if (!budget.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("SpendingLimit", "id", id);
        }
        return budget;
    }

    private void validateDateRange(LocalDate start, LocalDate end) {
        if (start.isAfter(end)) {
            throw new BadRequestException("Ngày bắt đầu phải trước hoặc bằng ngày kết thúc");
        }
    }

    LocalDate[] resolvePeriodDates(PeriodType periodType, LocalDate start, LocalDate end, LocalDate reference) {
        if (periodType == null) periodType = PeriodType.MONTHLY;
        LocalDate ref = reference != null ? reference : LocalDate.now();

        return switch (periodType) {
            case MONTHLY -> {
                LocalDate s = ref.withDayOfMonth(1);
                yield new LocalDate[]{s, s.with(TemporalAdjusters.lastDayOfMonth())};
            }
            case WEEKLY -> {
                LocalDate s = ref.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
                yield new LocalDate[]{s, s.plusDays(6)};
            }
            case YEARLY -> {
                LocalDate s = ref.withDayOfYear(1);
                yield new LocalDate[]{s, s.with(TemporalAdjusters.lastDayOfYear())};
            }
            case CUSTOM -> {
                if (start == null || end == null) {
                    throw new BadRequestException("Chu kỳ tùy chỉnh cần ngày bắt đầu và kết thúc");
                }
                yield new LocalDate[]{start, end};
            }
        };
    }

    private BigDecimal sumSpent(Long userId, Budget budget, Long excludeTransactionId) {
        BigDecimal spent = transactionRepository.sumAmountByUserCategoryTypeAndDateRangeExcluding(
                userId,
                budget.getCategory().getId(),
                TransactionType.EXPENSE,
                budget.getStartDate(),
                budget.getEndDate(),
                excludeTransactionId);
        return spent != null ? spent : BigDecimal.ZERO;
    }

    private BudgetDto mapToDto(Budget budget, Long userId, Long excludeTransactionId) {
        BigDecimal spent = sumSpent(userId, budget, excludeTransactionId);
        BigDecimal remaining = budget.getAmount().subtract(spent);
        int threshold = budget.getWarningThresholdPercent() != null ? budget.getWarningThresholdPercent() : 80;
        BigDecimal usagePercent = computeUsagePercent(spent, budget.getAmount());
        SpendingLimitStatus status = computeStatus(usagePercent, threshold);
        String statusMessage = buildStatusMessage(budget.getCategory().getName(), spent, budget.getAmount(), usagePercent, remaining, status);

        return BudgetDto.builder()
                .id(budget.getId())
                .amount(budget.getAmount())
                .limitAmount(budget.getAmount())
                .startDate(budget.getStartDate())
                .endDate(budget.getEndDate())
                .category(CategoryDto.builder()
                        .id(budget.getCategory().getId())
                        .name(budget.getCategory().getName())
                        .type(budget.getCategory().getType())
                        .icon(budget.getCategory().getIcon())
                        .build())
                .note(budget.getNote())
                .createdAt(budget.getCreatedAt())
                .periodType(budget.getPeriodType() != null ? budget.getPeriodType() : PeriodType.MONTHLY)
                .warningThresholdPercent(threshold)
                .isActive(budget.getIsActive() == null || budget.getIsActive())
                .alertsEnabled(budget.getAlertsEnabled() == null || budget.getAlertsEnabled())
                .spentAmount(spent)
                .currentSpent(spent)
                .remainingAmount(remaining)
                .usagePercent(usagePercent)
                .status(status)
                .statusMessage(statusMessage)
                .build();
    }

    BigDecimal computeUsagePercent(BigDecimal spent, BigDecimal limit) {
        if (limit == null || limit.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }
        return spent.multiply(BigDecimal.valueOf(100))
                .divide(limit, 2, RoundingMode.HALF_UP);
    }

    SpendingLimitStatus computeStatus(BigDecimal usagePercent, int threshold) {
        if (usagePercent.compareTo(BigDecimal.valueOf(100)) >= 0) {
            return SpendingLimitStatus.EXCEEDED;
        }
        if (usagePercent.compareTo(BigDecimal.valueOf(threshold)) >= 0) {
            return SpendingLimitStatus.WARNING;
        }
        return SpendingLimitStatus.SAFE;
    }

    private String formatVnd(BigDecimal amount) {
        return VND.format(amount.abs().setScale(0, RoundingMode.HALF_UP)) + "đ";
    }

    private String buildStatusMessage(String categoryName, BigDecimal spent, BigDecimal limit,
                                      BigDecimal usagePercent, BigDecimal remaining, SpendingLimitStatus status) {
        return switch (status) {
            case EXCEEDED -> String.format("Bạn đã vượt hạn mức %s %s trong kỳ này.",
                    categoryName, formatVnd(spent.subtract(limit)));
            case WARNING -> String.format("Bạn đã sử dụng %s%% hạn mức %s trong kỳ này.",
                    usagePercent.stripTrailingZeros().toPlainString(), categoryName);
            case SAFE -> remaining.compareTo(BigDecimal.ZERO) >= 0
                    ? String.format("Còn %s trong hạn mức %s.", formatVnd(remaining), categoryName)
                    : null;
        };
    }

    private String buildProjectedMessage(String categoryName, BigDecimal limit, BigDecimal projected,
                                         BigDecimal usagePercent, int threshold, SpendingLimitStatus status) {
        if (status == SpendingLimitStatus.EXCEEDED) {
            BigDecimal over = projected.subtract(limit);
            return String.format("Giao dịch này sẽ khiến danh mục %s vượt hạn mức %s.",
                    categoryName, formatVnd(over));
        }
        return String.format("Bạn sẽ sử dụng %s%% hạn mức %s sau giao dịch này.",
                usagePercent.stripTrailingZeros().toPlainString(), categoryName);
    }

    private SpendingLimitAlertDto toAlertDto(Budget budget, BudgetDto dto) {
        BigDecimal exceeded = dto.getRemainingAmount().compareTo(BigDecimal.ZERO) < 0
                ? dto.getRemainingAmount().abs() : BigDecimal.ZERO;
        return SpendingLimitAlertDto.builder()
                .limitId(budget.getId())
                .categoryId(budget.getCategory().getId())
                .categoryName(budget.getCategory().getName())
                .limitAmount(dto.getLimitAmount())
                .currentSpent(dto.getCurrentSpent())
                .remainingAmount(dto.getRemainingAmount())
                .usagePercent(dto.getUsagePercent())
                .exceededAmount(exceeded)
                .status(dto.getStatus())
                .message(dto.getStatusMessage())
                .build();
    }
}
