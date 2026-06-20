package com.expense.service;

import com.expense.dto.auth.AuthResponse;
import com.expense.dto.auth.RegisterRequest;
import com.expense.entity.PendingRegistration;
import com.expense.entity.User;
import com.expense.exception.BadRequestException;
import com.expense.repository.PendingRegistrationRepository;
import com.expense.repository.UserRepository;
import com.expense.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;

/**
 * Luồng đăng ký 2 bước:
 *   1. POST /auth/register/request {fullName, email, password, phone}
 *      → BCrypt password, sinh OTP 6 số (hash), lưu vào pending_registrations TTL 10 phút.
 *      → gửi mail OTP (hoặc log console nếu chưa cấu hình spring.mail).
 *   2. POST /auth/register/verify {email, otp}
 *      → tra OTP → tạo user thật trong bảng users + seed default categories → trả AuthResponse (auto-login).
 *   Tối đa 5 lần verify sai → xóa pending, yêu cầu request lại.
 */
@Service
@RequiredArgsConstructor
public class PendingRegistrationService {

    private static final Logger log = LoggerFactory.getLogger(PendingRegistrationService.class);
    private static final int OTP_TTL_MINUTES = 10;
    private static final int MAX_ATTEMPTS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PendingRegistrationRepository pendingRepository;
    private final PasswordEncoder passwordEncoder;
    private final CategoryService categoryService;
    private final JwtTokenProvider tokenProvider;
    private final EmailService emailService;

    @Value("${jwt.expiration-ms}")
    private long jwtExpirationMs;

    /** Bước 1: nhận thông tin đăng ký + gửi OTP. */
    @Transactional
    public void requestRegistration(RegisterRequest req) {
        String normalized = req.getEmail().trim().toLowerCase();
        if (userRepository.existsByEmail(normalized)) {
            throw new BadRequestException("Email đã được đăng ký");
        }

        pendingRepository.deleteAllByEmail(normalized);

        String otp = generateOtp();
        PendingRegistration pending = PendingRegistration.builder()
                .email(normalized)
                .fullName(req.getFullName().trim())
                .passwordHash(passwordEncoder.encode(req.getPassword()))
                .phone(req.getPhone())
                .otpHash(passwordEncoder.encode(otp))
                .expiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES))
                .attempts(0)
                .build();
        pendingRepository.save(pending);

        // Gửi mail bất đồng bộ — không block API. Client nhận response ngay sau khi DB save xong.
        emailService.sendRegistrationOtp(normalized, otp, req.getFullName());
        log.info("Da queue gui OTP dang ky cho {} (async)", normalized);
    }

    /** Bước 2: verify OTP → tạo user thật + return AuthResponse (auto-login). */
    @Transactional
    public AuthResponse verifyAndCreateUser(String email, String otp) {
        String normalized = email.trim().toLowerCase();

        if (userRepository.existsByEmail(normalized)) {
            // user đã được tạo (có thể do thao tác đôi) → reject tránh duplicate
            throw new BadRequestException("Email đã được đăng ký, hãy đăng nhập");
        }

        PendingRegistration pending = pendingRepository
                .findFirstByEmailOrderByCreatedAtDesc(normalized)
                .orElseThrow(() -> new BadRequestException(
                        "Không có yêu cầu đăng ký nào cho email này, hãy đăng ký lại"));

        if (pending.getExpiresAt().isBefore(LocalDateTime.now())) {
            pendingRepository.delete(pending);
            throw new BadRequestException("OTP đã hết hạn, vui lòng đăng ký lại");
        }

        if (pending.getAttempts() >= MAX_ATTEMPTS) {
            pendingRepository.delete(pending);
            throw new BadRequestException("Đã nhập sai quá nhiều lần. Vui lòng đăng ký lại");
        }

        if (!passwordEncoder.matches(otp, pending.getOtpHash())) {
            pending.setAttempts(pending.getAttempts() + 1);
            pendingRepository.save(pending);
            throw new BadRequestException(
                    "OTP không đúng (còn " + (MAX_ATTEMPTS - pending.getAttempts()) + " lần thử)");
        }

        // Tạo user thật (passwordHash đã BCrypt, không encode lại)
        User user = User.builder()
                .fullName(pending.getFullName())
                .email(normalized)
                .password(pending.getPasswordHash())
                .phone(pending.getPhone())
                .build();
        user = userRepository.save(user);
        categoryService.seedDefaultCategoriesIfEmpty(user);

        pendingRepository.deleteAllByEmail(normalized);

        String accessToken = tokenProvider.generateAccessToken(user.getEmail());
        String refreshToken = tokenProvider.generateRefreshToken(user.getEmail());
        log.info("User đăng ký + verify OTP thành công: {}", user.getEmail());

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000)
                .user(AuthResponse.UserInfo.builder()
                        .id(user.getId())
                        .fullName(user.getFullName())
                        .email(user.getEmail())
                        .phone(user.getPhone())
                        .botPersonality(user.getBotPersonality())
                        .botSetupCompleted(false)
                        .onboardingCompleted(false)
                        .currencyCode("VND")
                        .build())
                .build();
    }

    /** Gửi lại OTP (giữ nguyên thông tin đăng ký, chỉ thay OTP mới). */
    @Transactional
    public void resendOtp(String email) {
        String normalized = email.trim().toLowerCase();
        PendingRegistration pending = pendingRepository
                .findFirstByEmailOrderByCreatedAtDesc(normalized)
                .orElseThrow(() -> new BadRequestException("Không có yêu cầu đăng ký cho email này"));

        String otp = generateOtp();
        pending.setOtpHash(passwordEncoder.encode(otp));
        pending.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES));
        pending.setAttempts(0);
        pendingRepository.save(pending);

        emailService.sendRegistrationOtp(normalized, otp, pending.getFullName());
    }

    private static String generateOtp() {
        return String.format("%06d", RANDOM.nextInt(1_000_000));
    }
}
