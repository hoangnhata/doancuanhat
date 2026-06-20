package com.expense.service;

import com.expense.dto.user.UserDto;
import com.expense.dto.user.UserProfileRequest;
import com.expense.dto.user.UserUpdateRequest;
import com.expense.dto.user.ChangePasswordRequest;
import com.expense.entity.User;
import com.expense.exception.BadRequestException;
import com.expense.exception.ResourceNotFoundException;
import com.expense.repository.UserRepository;
import com.expense.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserDto getCurrentUser() {
        User user = getCurrentUserEntity();
        return mapToDto(user);
    }

    @Transactional
    public UserDto updateUser(UserUpdateRequest request) {
        User user = getCurrentUserEntity();
        if (request.getFullName() != null) user.setFullName(request.getFullName());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        user = userRepository.save(user);
        log.info("User updated: {}", user.getEmail());
        return mapToDto(user);
    }

    @Transactional
    public UserDto updateProfile(UserProfileRequest request) {
        User user = getCurrentUserEntity();
        if (request.getFullName() != null) user.setFullName(request.getFullName());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getBotPersonality() != null) {
            user.setBotPersonality(request.getBotPersonality());
            user.setBotSetupCompleted(true);
            user.setOnboardingStep("WALLET_SETUP");
        }
        if (Boolean.TRUE.equals(request.getBotSetupCompleted())) {
            user.setBotSetupCompleted(true);
            if (user.getOnboardingStep() == null) {
                user.setOnboardingStep("WALLET_SETUP");
            }
        }
        if (request.getWalletName() != null) user.setWalletName(request.getWalletName());
        if (request.getCurrencyCode() != null) user.setCurrencyCode(request.getCurrencyCode());
        if (request.getInitialBalance() != null) user.setInitialBalance(request.getInitialBalance());

        if (Boolean.TRUE.equals(request.getWalletSetupCompleted()) || request.getWalletName() != null) {
            user.setWalletSetupCompleted(true);
            user.setOnboardingStep("SAVING_GOAL_SETUP");
        }

        if (Boolean.TRUE.equals(request.getSavingGoalSetupSkipped())) {
            user.setSavingGoalSetupSkipped(true);
            user.setSavingGoalSetupCompleted(false);
            user.setOnboardingStep("SPENDING_LIMIT_SETUP");
            user.setOnboardingCompleted(false);
        }

        if (Boolean.TRUE.equals(request.getSavingGoalSetupCompleted())) {
            user.setSavingGoalSetupCompleted(true);
            user.setSavingGoalSetupSkipped(false);
            user.setOnboardingStep("SPENDING_LIMIT_SETUP");
            user.setOnboardingCompleted(false);
        }

        if (Boolean.TRUE.equals(request.getSpendingLimitSetupSkipped())) {
            user.setSpendingLimitSetupSkipped(true);
            user.setSpendingLimitSetupCompleted(false);
            user.setOnboardingCompleted(true);
            user.setOnboardingStep("COMPLETED");
        }

        if (Boolean.TRUE.equals(request.getSpendingLimitSetupCompleted())) {
            user.setSpendingLimitSetupCompleted(true);
            user.setSpendingLimitSetupSkipped(false);
            user.setOnboardingCompleted(true);
            user.setOnboardingStep("COMPLETED");
        }

        if (Boolean.TRUE.equals(request.getOnboardingCompleted())
                && !Boolean.TRUE.equals(request.getWalletSetupCompleted())
                && request.getSavingGoalSetupSkipped() == null
                && request.getSavingGoalSetupCompleted() == null
                && request.getSpendingLimitSetupSkipped() == null
                && request.getSpendingLimitSetupCompleted() == null) {
            user.setOnboardingCompleted(true);
            user.setOnboardingStep("COMPLETED");
            if (user.getWalletSetupCompleted() == null) {
                user.setWalletSetupCompleted(true);
            }
        }

        if (request.getOnboardingStep() != null) {
            user.setOnboardingStep(request.getOnboardingStep());
        }

        user = userRepository.save(user);
        log.info("User profile updated: {}", user.getEmail());
        return mapToDto(user);
    }

    @Transactional
    public void changePassword(ChangePasswordRequest request) {
        User user = getCurrentUserEntity();
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new BadRequestException("Mật khẩu hiện tại không đúng");
        }
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
        log.info("Password changed for user: {}", user.getEmail());
    }

    public User getCurrentUserEntity() {
        UserPrincipal principal = (UserPrincipal) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return userRepository.findById(principal.getId())
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", principal.getId()));
    }

    private boolean isBotSetupCompleted(User user) {
        if (Boolean.TRUE.equals(user.getBotSetupCompleted())) {
            return true;
        }
        // Người dùng cũ đã chọn tính cách trước khi có cờ bot_setup_completed
        return user.getBotPersonality() != null && !user.getBotPersonality().isBlank();
    }

    private UserDto mapToDto(User user) {
        return UserDto.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .botPersonality(user.getBotPersonality())
                .botSetupCompleted(isBotSetupCompleted(user))
                .onboardingCompleted(user.getOnboardingCompleted() != null ? user.getOnboardingCompleted() : false)
                .walletName(user.getWalletName())
                .currencyCode(user.getCurrencyCode() != null ? user.getCurrencyCode() : "VND")
                .initialBalance(user.getInitialBalance())
                .walletSetupCompleted(user.getWalletSetupCompleted() != null ? user.getWalletSetupCompleted() : false)
                .savingGoalSetupCompleted(user.getSavingGoalSetupCompleted() != null ? user.getSavingGoalSetupCompleted() : false)
                .savingGoalSetupSkipped(user.getSavingGoalSetupSkipped() != null ? user.getSavingGoalSetupSkipped() : false)
                .spendingLimitSetupCompleted(user.getSpendingLimitSetupCompleted() != null ? user.getSpendingLimitSetupCompleted() : false)
                .spendingLimitSetupSkipped(user.getSpendingLimitSetupSkipped() != null ? user.getSpendingLimitSetupSkipped() : false)
                .onboardingStep(user.getOnboardingStep())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
