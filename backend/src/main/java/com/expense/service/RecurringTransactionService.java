package com.expense.service;

import com.expense.dto.category.CategoryDto;
import com.expense.dto.recurring.RecurringTransactionDto;
import com.expense.dto.recurring.RecurringTransactionRequest;
import com.expense.entity.Category;
import com.expense.entity.RecurringTransaction;
import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.RecurringTransactionRepository;
import com.expense.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RecurringTransactionService {

    private static final Logger log = LoggerFactory.getLogger(RecurringTransactionService.class);

    private final RecurringTransactionRepository recurringRepository;
    private final TransactionRepository transactionRepository;
    private final UserService userService;
    private final CategoryService categoryService;

    public RecurringTransactionDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        RecurringTransaction rt = recurringRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("RecurringTransaction", "id", id));
        if (!rt.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("RecurringTransaction", "id", id);
        }
        return mapToDto(rt);
    }

    public List<RecurringTransactionDto> getAll() {
        User user = userService.getCurrentUserEntity();
        return recurringRepository.findByUserIdOrderByDayOfMonthAsc(user.getId()).stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public RecurringTransactionDto create(RecurringTransactionRequest request) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());

        RecurringTransaction rt = RecurringTransaction.builder()
                .type(request.getType())
                .amount(request.getAmount())
                .description(request.getDescription())
                .dayOfMonth(request.getDayOfMonth())
                .startDate(request.getStartDate())
                .endDate(request.getEndDate())
                .isActive(true)
                .category(category)
                .user(user)
                .build();
        rt = recurringRepository.save(rt);
        log.info("Recurring transaction created: {} for user {}", rt.getId(), user.getId());
        return mapToDto(rt);
    }

    @Transactional
    public RecurringTransactionDto update(Long id, RecurringTransactionRequest request) {
        User user = userService.getCurrentUserEntity();
        RecurringTransaction rt = recurringRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("RecurringTransaction", "id", id));
        if (!rt.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("RecurringTransaction", "id", id);
        }
        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());

        rt.setType(request.getType());
        rt.setAmount(request.getAmount());
        rt.setDescription(request.getDescription());
        rt.setDayOfMonth(request.getDayOfMonth());
        rt.setStartDate(request.getStartDate());
        rt.setEndDate(request.getEndDate());
        rt.setCategory(category);
        rt = recurringRepository.save(rt);
        return mapToDto(rt);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        RecurringTransaction rt = recurringRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("RecurringTransaction", "id", id));
        if (!rt.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("RecurringTransaction", "id", id);
        }
        recurringRepository.delete(rt);
    }

    @Transactional
    public void toggleActive(Long id) {
        User user = userService.getCurrentUserEntity();
        RecurringTransaction rt = recurringRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("RecurringTransaction", "id", id));
        if (!rt.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("RecurringTransaction", "id", id);
        }
        rt.setIsActive(!rt.getIsActive());
        recurringRepository.save(rt);
    }

    @Transactional
    public void processRecurringForDate(LocalDate date) {
        int day = date.getDayOfMonth();
        if (day > 28) return;

        List<RecurringTransaction> matching = recurringRepository.findByIsActiveTrueAndDayOfMonth(day);
        for (RecurringTransaction rt : matching) {
            if (date.isBefore(rt.getStartDate())) continue;
            if (rt.getEndDate() != null && date.isAfter(rt.getEndDate())) continue;

            if (transactionRepository.existsByRecurringTransactionIdAndTransactionDate(rt.getId(), date)) {
                continue;
            }

            Transaction tx = Transaction.builder()
                    .type(rt.getType())
                    .amount(rt.getAmount())
                    .description((rt.getDescription() != null ? rt.getDescription() + " " : "") + "[Định kỳ]")
                    .transactionDate(date)
                    .category(rt.getCategory())
                    .user(rt.getUser())
                    .recurringTransaction(rt)
                    .build();
            transactionRepository.save(tx);
            log.info("Created recurring transaction {} for date {}", tx.getId(), date);
        }
    }

    private RecurringTransactionDto mapToDto(RecurringTransaction rt) {
        return RecurringTransactionDto.builder()
                .id(rt.getId())
                .type(rt.getType())
                .amount(rt.getAmount())
                .description(rt.getDescription())
                .dayOfMonth(rt.getDayOfMonth())
                .startDate(rt.getStartDate())
                .endDate(rt.getEndDate())
                .isActive(rt.getIsActive())
                .category(CategoryDto.builder()
                        .id(rt.getCategory().getId())
                        .name(rt.getCategory().getName())
                        .type(rt.getCategory().getType())
                        .icon(rt.getCategory().getIcon())
                        .build())
                .build();
    }
}
