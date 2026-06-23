package com.expense.service;

import com.expense.dto.saving.SavingGoalDto;
import com.expense.dto.saving.SavingGoalRequest;
import com.expense.dto.saving.SavingSpendRequest;
import com.expense.dto.saving.SavingSpendResponse;
import com.expense.dto.saving.SavingTransactionDto;
import com.expense.dto.saving.SavingTransferRequest;
import com.expense.dto.category.CategoryDto;
import com.expense.dto.transaction.TransactionDto;
import com.expense.dto.wallet.WalletDto;
import com.expense.entity.Category;
import com.expense.entity.SavingGoal;
import com.expense.entity.SavingTransaction;
import com.expense.entity.Transaction;
import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.entity.enums.SavingGoalStatus;
import com.expense.entity.enums.SavingTransactionType;
import com.expense.entity.enums.TransactionType;
import com.expense.exception.BadRequestException;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.SavingGoalRepository;
import com.expense.repository.SavingTransactionRepository;
import com.expense.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SavingGoalService {

    private static final Logger log = LoggerFactory.getLogger(SavingGoalService.class);

    private final SavingGoalRepository savingGoalRepository;
    private final SavingTransactionRepository savingTransactionRepository;
    private final TransactionRepository transactionRepository;
    private final UserService userService;
    private final WalletService walletService;
    private final WalletBalanceService walletBalanceService;
    private final CategoryService categoryService;

    @Transactional
    public SavingGoalDto create(SavingGoalRequest request) {
        User user = userService.getCurrentUserEntity();

        BigDecimal initialAmount = request.getInitialAmount() != null ? request.getInitialAmount() : BigDecimal.ZERO;
        if (initialAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new BadRequestException("Số tiền ban đầu không được âm");
        }

        SavingGoalStatus status = resolveStatus(initialAmount, request.getTargetAmount(), request.getStatus());

        SavingGoal goal = SavingGoal.builder()
                .name(request.getName().trim())
                .targetAmount(request.getTargetAmount())
                .currentAmount(initialAmount)
                .targetDate(request.getTargetDate())
                .status(status)
                .note(request.getNote())
                .user(user)
                .build();

        updateGoalStatus(goal);
        goal = savingGoalRepository.save(goal);
        log.info("Saving goal created: {} for user {}", goal.getId(), user.getId());
        return mapToDto(goal);
    }

    @Transactional
    public List<SavingGoalDto> getAll() {
        User user = userService.getCurrentUserEntity();
        return savingGoalRepository.findByUserIdOrderByCreatedAtDesc(user.getId()).stream()
                .map(this::backfillCompletionMetadataIfNeeded)
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public SavingGoalDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);
        return mapToDto(goal);
    }

    @Transactional
    public SavingGoalDto update(Long id, SavingGoalRequest request) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);

        if (goal.getStatus() == SavingGoalStatus.CANCELLED) {
            throw new BadRequestException("Không thể cập nhật mục tiêu đã hủy");
        }

        goal.setName(request.getName().trim());
        goal.setTargetAmount(request.getTargetAmount());
        goal.setTargetDate(request.getTargetDate());
        goal.setNote(request.getNote());

        if (request.getStatus() != null &&
                (request.getStatus() == SavingGoalStatus.PAUSED || request.getStatus() == SavingGoalStatus.ACTIVE)) {
            goal.setStatus(request.getStatus());
        }

        updateGoalStatus(goal);
        goal = savingGoalRepository.save(goal);
        log.info("Saving goal updated: {}", goal.getId());
        return mapToDto(goal);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);

        if (goal.getCurrentAmount().compareTo(BigDecimal.ZERO) > 0) {
            throw new BadRequestException("Không thể xóa mục tiêu còn số dư. Hãy rút hết tiền trước.");
        }

        savingGoalRepository.delete(goal);
        log.info("Saving goal deleted: {}", id);
    }

    @Transactional
    public SavingGoalDto deposit(Long id, SavingTransferRequest request) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);

        validateTransferAllowed(goal, true);
        validatePositiveAmount(request.getAmount());

        Wallet wallet = walletService.getWalletEntity(request.getWalletId(), user.getId());
        BigDecimal walletBalance = walletBalanceService.getCurrentBalance(user.getId(), wallet);
        if (walletBalance.compareTo(request.getAmount()) < 0) {
            throw new BadRequestException("Ví nguồn không đủ số dư");
        }

        goal.setCurrentAmount(goal.getCurrentAmount().add(request.getAmount()));
        updateGoalStatus(goal);
        savingGoalRepository.save(goal);

        SavingTransaction tx = SavingTransaction.builder()
                .savingGoal(goal)
                .wallet(wallet)
                .user(user)
                .amount(request.getAmount())
                .type(SavingTransactionType.DEPOSIT)
                .note(request.getNote())
                .build();
        savingTransactionRepository.save(tx);

        log.info("Saving deposit: {} VND to goal {} from wallet {}", request.getAmount(), id, wallet.getId());
        return mapToDto(goal);
    }

    @Transactional
    public SavingGoalDto withdraw(Long id, SavingTransferRequest request) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);

        validateTransferAllowed(goal, false);
        validatePositiveAmount(request.getAmount());

        if (goal.getCurrentAmount().compareTo(request.getAmount()) < 0) {
            throw new BadRequestException("Mục tiêu tiết kiệm không đủ số dư");
        }

        Wallet wallet = walletService.getWalletEntity(request.getWalletId(), user.getId());

        goal.setCurrentAmount(goal.getCurrentAmount().subtract(request.getAmount()));
        updateGoalStatus(goal);
        savingGoalRepository.save(goal);

        SavingTransaction tx = SavingTransaction.builder()
                .savingGoal(goal)
                .wallet(wallet)
                .user(user)
                .amount(request.getAmount())
                .type(SavingTransactionType.WITHDRAW)
                .note(request.getNote())
                .build();
        savingTransactionRepository.save(tx);

        log.info("Saving withdraw: {} VND from goal {} to wallet {}", request.getAmount(), id, wallet.getId());
        return mapToDto(goal);
    }

    @Transactional
    public SavingSpendResponse spendFromGoal(Long id, SavingSpendRequest request) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);

        if (goal.getStatus() != SavingGoalStatus.COMPLETED) {
            throw new BadRequestException("Chỉ mục tiêu đã hoàn thành mới có thể chi tiêu");
        }

        validatePositiveAmount(request.getAmount());

        if (goal.getCurrentAmount().compareTo(request.getAmount()) < 0) {
            throw new BadRequestException("Số tiền vượt quá số dư mục tiêu");
        }

        Category category = categoryService.getCategoryEntity(request.getCategoryId(), user.getId());
        Wallet wallet = walletService.getWalletEntity(request.getWalletId(), user.getId());

        Transaction transaction = Transaction.builder()
                .type(TransactionType.EXPENSE)
                .amount(request.getAmount())
                .description(request.getDescription())
                .transactionDate(request.getTransactionDate())
                .category(category)
                .wallet(wallet)
                .user(user)
                .savingGoal(goal)
                .build();
        transaction = transactionRepository.save(transaction);

        goal.setCurrentAmount(goal.getCurrentAmount().subtract(request.getAmount()));
        goal.setStatus(SavingGoalStatus.USED);
        savingGoalRepository.save(goal);

        SavingTransaction savingTx = SavingTransaction.builder()
                .savingGoal(goal)
                .wallet(wallet)
                .user(user)
                .amount(request.getAmount())
                .type(SavingTransactionType.SPEND)
                .note(request.getDescription())
                .linkedTransaction(transaction)
                .build();
        savingTransactionRepository.save(savingTx);

        log.info("Saving spend: {} VND from goal {} linked to transaction {}", request.getAmount(), id, transaction.getId());

        return SavingSpendResponse.builder()
                .savingGoal(mapToDto(goal))
                .transaction(mapExpenseToDto(transaction))
                .build();
    }

    @Transactional(readOnly = true)
    public List<SavingTransactionDto> getTransactions(Long id) {
        User user = userService.getCurrentUserEntity();
        SavingGoal goal = getGoalEntity(user.getId(), id);
        return savingTransactionRepository.findBySavingGoalIdOrderByCreatedAtDesc(goal.getId()).stream()
                .map(this::mapTransactionToDto)
                .collect(Collectors.toList());
    }

    private SavingGoal getGoalEntity(Long userId, Long id) {
        return savingGoalRepository.findByUserIdAndId(userId, id)
                .orElseThrow(() -> new ResourceNotFoundException("SavingGoal", "id", id));
    }

    private void validateTransferAllowed(SavingGoal goal, boolean isDeposit) {
        if (goal.getStatus() == SavingGoalStatus.CANCELLED) {
            throw new BadRequestException("Không thể thao tác trên mục tiêu đã hủy");
        }
        if (goal.getStatus() == SavingGoalStatus.USED) {
            throw new BadRequestException("Mục tiêu đã được sử dụng");
        }
        if (goal.getStatus() == SavingGoalStatus.PAUSED) {
            throw new BadRequestException("Mục tiêu đang tạm dừng. Hãy kích hoạt lại trước khi nạp/rút.");
        }
        if (isDeposit && goal.getStatus() == SavingGoalStatus.COMPLETED) {
            throw new BadRequestException("Mục tiêu đã hoàn thành, không thể nạp thêm tiền");
        }
    }

    private void validatePositiveAmount(BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("Số tiền phải lớn hơn 0");
        }
    }

    private SavingGoalStatus resolveStatus(BigDecimal current, BigDecimal target, SavingGoalStatus requested) {
        if (requested == SavingGoalStatus.CANCELLED || requested == SavingGoalStatus.PAUSED) {
            return requested;
        }
        if (current.compareTo(target) >= 0) {
            return SavingGoalStatus.COMPLETED;
        }
        return SavingGoalStatus.ACTIVE;
    }

    private void updateGoalStatus(SavingGoal goal) {
        if (goal.getStatus() == SavingGoalStatus.CANCELLED
                || goal.getStatus() == SavingGoalStatus.PAUSED
                || goal.getStatus() == SavingGoalStatus.USED) {
            return;
        }
        if (goal.getCurrentAmount().compareTo(goal.getTargetAmount()) >= 0) {
            if (goal.getCompletedAt() == null) {
                goal.setCompletedAt(LocalDateTime.now());
                goal.setCompletedAmount(goal.getCurrentAmount());
            }
            goal.setStatus(SavingGoalStatus.COMPLETED);
        } else if (goal.getStatus() == SavingGoalStatus.COMPLETED) {
            goal.setStatus(SavingGoalStatus.ACTIVE);
            goal.setCompletedAt(null);
            goal.setCompletedAmount(null);
        }
    }

    private SavingGoalDto mapToDto(SavingGoal goal) {
        BigDecimal remaining = goal.getTargetAmount().subtract(goal.getCurrentAmount());
        if (remaining.compareTo(BigDecimal.ZERO) < 0) {
            remaining = BigDecimal.ZERO;
        }

        BigDecimal progress = BigDecimal.ZERO;
        if (goal.getTargetAmount().compareTo(BigDecimal.ZERO) > 0) {
            progress = goal.getCurrentAmount()
                    .multiply(BigDecimal.valueOf(100))
                    .divide(goal.getTargetAmount(), 2, RoundingMode.HALF_UP);
        }

        boolean completed = goal.getCurrentAmount().compareTo(goal.getTargetAmount()) >= 0
                || goal.getStatus() == SavingGoalStatus.COMPLETED
                || goal.getStatus() == SavingGoalStatus.USED;

        BigDecimal totalSaved = goal.getCompletedAmount() != null
                ? goal.getCompletedAmount()
                : goal.getCurrentAmount();

        LocalDateTime completedAt = resolveCompletedAt(goal);

        return SavingGoalDto.builder()
                .id(goal.getId())
                .name(goal.getName())
                .targetAmount(goal.getTargetAmount())
                .currentAmount(goal.getCurrentAmount())
                .targetDate(goal.getTargetDate())
                .status(goal.getStatus())
                .note(goal.getNote())
                .remainingAmount(remaining)
                .progressPercent(progress)
                .isCompleted(completed)
                .completedAt(completedAt)
                .durationDays(computeDurationDays(goal, completedAt))
                .totalSavedAmount(totalSaved)
                .createdAt(goal.getCreatedAt())
                .updatedAt(goal.getUpdatedAt())
                .build();
    }

    private SavingGoal backfillCompletionMetadataIfNeeded(SavingGoal goal) {
        if ((goal.getStatus() == SavingGoalStatus.COMPLETED || goal.getStatus() == SavingGoalStatus.USED)
                && goal.getCompletedAt() == null) {
            goal.setCompletedAt(goal.getUpdatedAt() != null ? goal.getUpdatedAt() : goal.getCreatedAt());
            if (goal.getCompletedAmount() == null) {
                goal.setCompletedAmount(goal.getCurrentAmount().max(goal.getTargetAmount()));
            }
            return savingGoalRepository.save(goal);
        }
        return goal;
    }

    private LocalDateTime resolveCompletedAt(SavingGoal goal) {
        if (goal.getCompletedAt() != null) {
            return goal.getCompletedAt();
        }
        if (goal.getStatus() == SavingGoalStatus.COMPLETED || goal.getStatus() == SavingGoalStatus.USED) {
            return goal.getUpdatedAt() != null ? goal.getUpdatedAt() : goal.getCreatedAt();
        }
        if (goal.getCurrentAmount().compareTo(goal.getTargetAmount()) >= 0) {
            return goal.getUpdatedAt() != null ? goal.getUpdatedAt() : goal.getCreatedAt();
        }
        return null;
    }

    private Long computeDurationDays(SavingGoal goal, LocalDateTime completedAt) {
        if (completedAt == null || goal.getCreatedAt() == null) {
            return null;
        }
        return ChronoUnit.DAYS.between(goal.getCreatedAt().toLocalDate(), completedAt.toLocalDate());
    }

    private TransactionDto mapExpenseToDto(Transaction transaction) {
        WalletDto walletDto = null;
        if (transaction.getWallet() != null) {
            Wallet w = transaction.getWallet();
            walletDto = WalletDto.builder()
                    .id(w.getId())
                    .name(w.getName())
                    .currencyCode(w.getCurrencyCode())
                    .initialBalance(w.getInitialBalance())
                    .isDefault(w.getIsDefault())
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

    private SavingTransactionDto mapTransactionToDto(SavingTransaction tx) {
        Wallet wallet = tx.getWallet();
        WalletDto walletDto = WalletDto.builder()
                .id(wallet.getId())
                .name(wallet.getName())
                .currencyCode(wallet.getCurrencyCode())
                .initialBalance(wallet.getInitialBalance())
                .isDefault(wallet.getIsDefault())
                .build();

        return SavingTransactionDto.builder()
                .id(tx.getId())
                .savingGoalId(tx.getSavingGoal().getId())
                .wallet(walletDto)
                .amount(tx.getAmount())
                .type(tx.getType())
                .note(tx.getNote())
                .createdAt(tx.getCreatedAt())
                .build();
    }
}
