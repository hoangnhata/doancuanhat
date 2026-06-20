package com.expense.service;

import com.expense.dto.wallet.WalletDto;
import com.expense.dto.wallet.WalletRequest;
import com.expense.entity.User;
import com.expense.entity.Wallet;
import com.expense.exception.BadRequestException;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class WalletService {

    private static final Logger log = LoggerFactory.getLogger(WalletService.class);

    private final WalletRepository walletRepository;
    private final UserService userService;
    private final WalletBalanceService walletBalanceService;

    public List<WalletDto> getAll() {
        User user = userService.getCurrentUserEntity();
        List<Wallet> wallets = walletRepository.findByUserIdOrderByIsDefaultDescNameAsc(user.getId());
        if (wallets.isEmpty()) {
            ensureDefaultWallet(user);
            wallets = walletRepository.findByUserIdOrderByIsDefaultDescNameAsc(user.getId());
        }
        return wallets.stream().map(this::mapToDto).collect(Collectors.toList());
    }

    public WalletDto getById(Long id) {
        User user = userService.getCurrentUserEntity();
        Wallet wallet = walletRepository.findByUserIdAndId(user.getId(), id)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet", "id", id));
        return mapToDto(wallet);
    }

    public Wallet getWalletEntity(Long walletId, Long userId) {
        if (walletId == null) {
            return getDefaultWalletForUser(userId);
        }
        return walletRepository.findByUserIdAndId(userId, walletId)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet", "id", walletId));
    }

    public Wallet getDefaultWalletForUser(Long userId) {
        User user = userService.getCurrentUserEntity();
        if (!user.getId().equals(userId)) {
            throw new ResourceNotFoundException("Wallet", "userId", userId);
        }
        Wallet defaultWallet = walletRepository.findByUserIdAndIsDefaultTrue(user.getId()).orElse(null);
        if (defaultWallet == null) {
            defaultWallet = ensureDefaultWallet(user);
        }
        return defaultWallet;
    }

    @Transactional
    public Wallet ensureDefaultWallet(User user) {
        Wallet existing = walletRepository.findByUserIdAndIsDefaultTrue(user.getId()).orElse(null);
        if (existing != null) return existing;

        String name = user.getWalletName() != null && !user.getWalletName().isBlank()
                ? user.getWalletName() : "Ví chính";
        String currency = user.getCurrencyCode() != null && !user.getCurrencyCode().isBlank()
                ? user.getCurrencyCode() : "VND";
        BigDecimal balance = user.getInitialBalance() != null ? user.getInitialBalance() : BigDecimal.ZERO;

        Wallet wallet = Wallet.builder()
                .name(name)
                .currencyCode(currency)
                .initialBalance(balance)
                .isDefault(true)
                .user(user)
                .build();
        wallet = walletRepository.save(wallet);
        log.info("Created default wallet for user {}", user.getId());
        return wallet;
    }

    @Transactional
    public WalletDto create(WalletRequest request) {
        User user = userService.getCurrentUserEntity();
        boolean setAsDefault = Boolean.TRUE.equals(request.getIsDefault());

        if (setAsDefault) {
            walletRepository.findByUserIdAndIsDefaultTrue(user.getId())
                    .ifPresent(w -> {
                        w.setIsDefault(false);
                        walletRepository.save(w);
                    });
        } else if (!walletRepository.existsByUserId(user.getId())) {
            setAsDefault = true;
        }

        Wallet wallet = Wallet.builder()
                .name(request.getName())
                .currencyCode(request.getCurrencyCode())
                .initialBalance(request.getInitialBalance() != null ? request.getInitialBalance() : BigDecimal.ZERO)
                .isDefault(setAsDefault)
                .user(user)
                .build();
        wallet = walletRepository.save(wallet);
        log.info("Wallet created: {} for user {}", wallet.getName(), user.getId());
        return mapToDto(wallet);
    }

    @Transactional
    public WalletDto update(Long id, WalletRequest request) {
        User user = userService.getCurrentUserEntity();
        Wallet wallet = walletRepository.findByUserIdAndId(user.getId(), id)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet", "id", id));

        wallet.setName(request.getName());
        wallet.setCurrencyCode(request.getCurrencyCode());
        wallet.setInitialBalance(request.getInitialBalance() != null ? request.getInitialBalance() : BigDecimal.ZERO);

        if (Boolean.TRUE.equals(request.getIsDefault()) && !wallet.getIsDefault()) {
            walletRepository.findByUserIdAndIsDefaultTrue(user.getId())
                    .ifPresent(w -> {
                        w.setIsDefault(false);
                        walletRepository.save(w);
                    });
            wallet.setIsDefault(true);
        }

        wallet = walletRepository.save(wallet);
        log.info("Wallet updated: {}", wallet.getId());
        return mapToDto(wallet);
    }

    @Transactional
    public void delete(Long id) {
        User user = userService.getCurrentUserEntity();
        Wallet wallet = walletRepository.findByUserIdAndId(user.getId(), id)
                .orElseThrow(() -> new ResourceNotFoundException("Wallet", "id", id));

        if (wallet.getIsDefault()) {
            throw new BadRequestException("Không thể xóa ví mặc định. Hãy đặt ví khác làm mặc định trước.");
        }

        walletRepository.delete(wallet);
        log.info("Wallet deleted: {}", id);
    }

    private WalletDto mapToDto(Wallet wallet) {
        User user = wallet.getUser();
        Long userId = user != null ? user.getId() : userService.getCurrentUserEntity().getId();
        BigDecimal currentBalance = walletBalanceService.getCurrentBalance(userId, wallet);
        return WalletDto.builder()
                .id(wallet.getId())
                .name(wallet.getName())
                .currencyCode(wallet.getCurrencyCode())
                .initialBalance(wallet.getInitialBalance())
                .currentBalance(currentBalance)
                .isDefault(wallet.getIsDefault())
                .createdAt(wallet.getCreatedAt())
                .build();
    }
}
