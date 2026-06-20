package com.expense.service;

import com.expense.dto.user.OnboardingStatusDto;
import com.expense.dto.user.UserDto;
import com.expense.entity.User;
import com.expense.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class OnboardingService {

    private final UserService userService;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public OnboardingStatusDto getStatus() {
        User user = userService.getCurrentUserEntity();
        return mapStatus(user);
    }

    @Transactional
    public UserDto skipSavingGoal() {
        User user = userService.getCurrentUserEntity();
        user.setSavingGoalSetupSkipped(true);
        user.setSavingGoalSetupCompleted(false);
        user.setOnboardingStep("SPENDING_LIMIT_SETUP");
        user.setOnboardingCompleted(false);
        user = userRepository.save(user);
        return userService.getCurrentUser();
    }

    @Transactional
    public UserDto completeSavingGoal() {
        User user = userService.getCurrentUserEntity();
        user.setSavingGoalSetupCompleted(true);
        user.setSavingGoalSetupSkipped(false);
        user.setOnboardingStep("SPENDING_LIMIT_SETUP");
        user.setOnboardingCompleted(false);
        user = userRepository.save(user);
        return userService.getCurrentUser();
    }

    @Transactional
    public UserDto skipSpendingLimit() {
        User user = userService.getCurrentUserEntity();
        user.setSpendingLimitSetupSkipped(true);
        user.setSpendingLimitSetupCompleted(false);
        user.setOnboardingCompleted(true);
        user.setOnboardingStep("COMPLETED");
        user = userRepository.save(user);
        return userService.getCurrentUser();
    }

    @Transactional
    public UserDto completeSpendingLimit() {
        User user = userService.getCurrentUserEntity();
        user.setSpendingLimitSetupCompleted(true);
        user.setSpendingLimitSetupSkipped(false);
        user.setOnboardingCompleted(true);
        user.setOnboardingStep("COMPLETED");
        user = userRepository.save(user);
        return userService.getCurrentUser();
    }

    private OnboardingStatusDto mapStatus(User user) {
        return OnboardingStatusDto.builder()
                .walletSetupCompleted(Boolean.TRUE.equals(user.getWalletSetupCompleted()))
                .savingGoalSetupCompleted(Boolean.TRUE.equals(user.getSavingGoalSetupCompleted()))
                .savingGoalSetupSkipped(Boolean.TRUE.equals(user.getSavingGoalSetupSkipped()))
                .spendingLimitSetupCompleted(Boolean.TRUE.equals(user.getSpendingLimitSetupCompleted()))
                .spendingLimitSetupSkipped(Boolean.TRUE.equals(user.getSpendingLimitSetupSkipped()))
                .onboardingCompleted(Boolean.TRUE.equals(user.getOnboardingCompleted()))
                .onboardingStep(user.getOnboardingStep())
                .build();
    }
}
