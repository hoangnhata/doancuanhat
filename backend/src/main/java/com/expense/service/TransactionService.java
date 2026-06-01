package com.expense.service;

import com.expense.dto.category.CategoryDto;
import com.expense.dto.common.PageResponse;
import com.expense.dto.transaction.TransactionDto;
import com.expense.dto.transaction.TransactionRequest;
import com.expense.dto.wallet.WalletDto;
import com.expense.entity.Category;
import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.entity.enums.TransactionType;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.TransactionRepository;
import com.expense.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TransactionService {

    private static final Logger log = LoggerFactory.getLogger(TransactionService.class);

    private final TransactionRepository transactionRepository;
    private final WalletRepository walletRepository;
    private final UserService userService;
    private final CategoryService categoryService;
    private final WalletService walletService;

    @Transactional
    public TransactionDto create(TransactionRequest request) {
        User user = userService.getCurrentUserEntity();
        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());
        Wallet wallet = walletService.getWalletEntity(request.getWalletId(), user.getId());

        Transaction transaction = Transaction.builder()
                .type(request.getType())
                .amount(request.getAmount())
                .description(request.getDescription())
                .transactionDate(request.getTransactionDate())
                .category(category)
                .wallet(wallet)
                .user(user)
                .build();

        transaction = transactionRepository.save(transaction);
        log.info("Transaction created: {} for user {}", transaction.getId(), user.getId());

        return mapToDto(transaction);
    }

    @Transactional(readOnly = true)
    public TransactionDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        Transaction transaction = transactionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", "id", id));

        if (!transaction.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Transaction", "id", id);
        }

        return mapToDto(transaction);
    }

    @Transactional(readOnly = true)
    public PageResponse<TransactionDto> getAll(Pageable pageable, TransactionType type,
                                                Long categoryId, Long walletId, LocalDate startDate, LocalDate endDate) {
        User user = userService.getCurrentUserEntity();
        boolean includeLegacy = walletId != null && walletRepository.findByUserIdAndIsDefaultTrue(user.getId())
                .map(w -> w.getId().equals(walletId))
                .orElse(false);
        Page<Transaction> page = transactionRepository.findByUserIdWithFilters(
                user.getId(), walletId, includeLegacy, type, categoryId, startDate, endDate, pageable);

        return PageResponse.<TransactionDto>builder()
                .content(page.getContent().stream().map(this::mapToDto).collect(Collectors.toList()))
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .build();
    }

    @Transactional
    public TransactionDto update(Long id, TransactionRequest request) {
        User user = userService.getCurrentUserEntity();
        Transaction transaction = transactionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", "id", id));

        if (!transaction.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Transaction", "id", id);
        }

        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());
        Wallet wallet = walletService.getWalletEntity(request.getWalletId(), user.getId());

        transaction.setType(request.getType());
        transaction.setAmount(request.getAmount());
        transaction.setDescription(request.getDescription());
        transaction.setTransactionDate(request.getTransactionDate());
        transaction.setCategory(category);
        transaction.setWallet(wallet);

        transaction = transactionRepository.save(transaction);
        log.info("Transaction updated: {}", transaction.getId());

        return mapToDto(transaction);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        Transaction transaction = transactionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Transaction", "id", id));

        if (!transaction.getUser().getId().equals(user.getId())) {
            throw new ResourceNotFoundException("Transaction", "id", id);
        }

        transactionRepository.delete(transaction);
        log.info("Transaction deleted: {}", id);
    }

    private TransactionDto mapToDto(Transaction transaction) {
        WalletDto walletDto = null;
        if (transaction.getWallet() != null) {
            walletDto = WalletDto.builder()
                    .id(transaction.getWallet().getId())
                    .name(transaction.getWallet().getName())
                    .currencyCode(transaction.getWallet().getCurrencyCode())
                    .initialBalance(transaction.getWallet().getInitialBalance())
                    .isDefault(transaction.getWallet().getIsDefault())
                    .build();
        }
        return TransactionDto.builder()
                .id(transaction.getId())
                .type(transaction.getType())
                .amount(transaction.getAmount())
                .description(transaction.getDescription())
                .transactionDate(transaction.getTransactionDate())
                .category(CategoryDto.builder()
                        .id(transaction.getCategory().getId())
                        .name(transaction.getCategory().getName())
                        .type(transaction.getCategory().getType())
                        .icon(transaction.getCategory().getIcon())
                        .build())
                .wallet(walletDto)
                .createdAt(transaction.getCreatedAt())
                .build();
    }
}
