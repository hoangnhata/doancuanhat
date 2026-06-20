package com.expense.service;

import com.expense.dto.auth.AuthResponse;
import com.expense.dto.auth.LoginRequest;
import com.expense.dto.auth.RegisterRequest;
import com.expense.entity.User;
import com.expense.exception.BadRequestException;
import com.expense.repository.UserRepository;
import com.expense.security.JwtTokenProvider;
import com.expense.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;
    private final CategoryService categoryService;

    @Value("${jwt.expiration-ms}")
    private long jwtExpirationMs;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        log.info("Registering new user with email: {}", request.getEmail());

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email already registered");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .phone(request.getPhone())
                .build();

        user = userRepository.save(user);
        log.info("User registered successfully: {}", user.getEmail());

        categoryService.seedDefaultCategoriesIfEmpty(user);

        String accessToken = tokenProvider.generateAccessToken(user.getEmail());
        String refreshToken = tokenProvider.generateRefreshToken(user.getEmail());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000)
                .user(buildUserInfo(user))
                .build();
    }

    public AuthResponse login(LoginRequest request) {
        log.info("Login attempt for email: {}", request.getEmail());

        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );

        SecurityContextHolder.getContext().setAuthentication(authentication);
        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();

        String accessToken = tokenProvider.generateAccessToken(authentication);
        String refreshToken = tokenProvider.generateRefreshToken(userPrincipal.getEmail());

        User user = userRepository.findById(userPrincipal.getId())
                .orElseThrow(() -> new BadRequestException("User not found"));

        categoryService.seedDefaultCategoriesIfEmpty(user);

        log.info("User logged in successfully: {}", user.getEmail());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000)
                .user(buildUserInfo(user))
                .build();
    }

    public AuthResponse refreshToken(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BadRequestException("User not found"));

        String accessToken = tokenProvider.generateAccessToken(email);
        String refreshToken = tokenProvider.generateRefreshToken(email);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000)
                .user(buildUserInfo(user))
                .build();
    }

    private boolean isBotSetupCompleted(User user) {
        if (Boolean.TRUE.equals(user.getBotSetupCompleted())) {
            return true;
        }
        return user.getBotPersonality() != null && !user.getBotPersonality().isBlank();
    }

    private AuthResponse.UserInfo buildUserInfo(User user) {
        return AuthResponse.UserInfo.builder()
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
                .build();
    }
}
