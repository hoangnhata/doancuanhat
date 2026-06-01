package com.expense.service;

import com.expense.dto.budget.BudgetDto;
import com.expense.dto.budget.BudgetRequest;
import com.expense.dto.category.CategoryDto;
import com.expense.dto.common.PageResponse;
import com.expense.entity.Budget;
import com.expense.entity.Category;
import com.expense.entity.User;
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
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class BudgetService {

    private static final Logger log = LoggerFactory.getLogger(BudgetService.class);

    private final BudgetRepository budgetRepository;
    private final TransactionRepository transactionRepository;
    private final UserService userService;
    private final CategoryService categoryService;

    @Transactional
    public BudgetDto create(BudgetRequest request) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());

        if (request.getStartDate().isAfter(request.getEndDate())) {
            throw new BadRequestException("Ngày bắt đầu phải trước hoặc bằng ngày kết thúc");
        }

        Budget budget = Budget.builder()
                .amount(request.getAmount())
                .startDate(request.getStartDate())
                .endDate(request.getEndDate())
                .category(category)
                .user(user)
                .note(request.getNote())
                .build();

        budget = budgetRepository.save(budget);
        log.info("Budget created: {} for user {}", budget.getId(), user.getId());

        return mapToDto(budget, user.getId());
    }

    @Transactional(readOnly = true)
    public BudgetDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        Budget budget = budgetRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Budget", "id", id));

        if (!budget.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Budget", "id", id);
        }

        return mapToDto(budget, user.getId());
    }

    @Transactional(readOnly = true)
    public PageResponse<BudgetDto> getAll(Pageable pageable) {
        User user = userService.getCurrentUserEntity();
        Page<Budget> page = budgetRepository.findByUserId(user.getId(), pageable);

        return PageResponse.<BudgetDto>builder()
                .content(page.getContent().stream()
                        .map(b -> mapToDto(b, user.getId()))
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
                .map(b -> mapToDto(b, user.getId()))
                .collect(Collectors.toList());
    }

    @Transactional
    public BudgetDto update(Long id, BudgetRequest request) {
        User user = userService.getCurrentUserEntity();
        Budget budget = budgetRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Budget", "id", id));

        if (!budget.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Budget", "id", id);
        }

        if (request.getStartDate().isAfter(request.getEndDate())) {
            throw new BadRequestException("Ngày bắt đầu phải trước hoặc bằng ngày kết thúc");
        }

        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());

        budget.setAmount(request.getAmount());
        budget.setStartDate(request.getStartDate());
        budget.setEndDate(request.getEndDate());
        budget.setCategory(category);
        budget.setNote(request.getNote());

        budget = budgetRepository.save(budget);
        log.info("Budget updated: {}", budget.getId());

        return mapToDto(budget, user.getId());
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        Budget budget = budgetRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Budget", "id", id));

        if (!budget.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Budget", "id", id);
        }

        budgetRepository.delete(budget);
        log.info("Budget deleted: {}", id);
    }

    private BudgetDto mapToDto(Budget budget, Long userId) {
        BigDecimal spent = transactionRepository.sumAmountByUserCategoryTypeAndDateRange(
                userId,
                budget.getCategory().getId(),
                TransactionType.EXPENSE,
                budget.getStartDate(),
                budget.getEndDate());
        if (spent == null) {
            spent = BigDecimal.ZERO;
        }
        BigDecimal remaining = budget.getAmount().subtract(spent);

        return BudgetDto.builder()
                .id(budget.getId())
                .amount(budget.getAmount())
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
                .spentAmount(spent)
                .remainingAmount(remaining)
                .build();
    }
}
