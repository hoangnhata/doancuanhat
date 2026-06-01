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
        if (request.getBotPersonality() != null) user.setBotPersonality(request.getBotPersonality());
        if (request.getOnboardingCompleted() != null) user.setOnboardingCompleted(request.getOnboardingCompleted());
        if (request.getWalletName() != null) user.setWalletName(request.getWalletName());
        if (request.getCurrencyCode() != null) user.setCurrencyCode(request.getCurrencyCode());
        if (request.getInitialBalance() != null) user.setInitialBalance(request.getInitialBalance());
        if (request.getSavingsGoalMonthly() != null) user.setSavingsGoalMonthly(request.getSavingsGoalMonthly());
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

    private UserDto mapToDto(User user) {
        return UserDto.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .botPersonality(user.getBotPersonality() != null ? user.getBotPersonality() : "HAPPY")
                .onboardingCompleted(user.getOnboardingCompleted() != null ? user.getOnboardingCompleted() : false)
                .walletName(user.getWalletName())
                .currencyCode(user.getCurrencyCode() != null ? user.getCurrencyCode() : "VND")
                .initialBalance(user.getInitialBalance())
                .savingsGoalMonthly(user.getSavingsGoalMonthly())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
