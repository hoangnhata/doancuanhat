package com.expense.service;

import com.expense.entity.PasswordResetToken;
import com.expense.entity.User;
import com.expense.exception.BadRequestException;
import com.expense.repository.PasswordResetTokenRepository;
import com.expense.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Optional;

/**
 * Luồng quên mật khẩu:
 *   1. POST /auth/forgot-password { email }
 *      → sinh OTP 6 số, hash BCrypt + lưu DB, TTL 10 phút.
 *      → gửi email (nếu spring.mail đã cấu hình). Nếu chưa cấu hình → log OTP ra console (dev mode).
 *      → response luôn 200 dù email không tồn tại (tránh leak danh sách email).
 *   2. POST /auth/reset-password { email, otp, newPassword }
 *      → kiểm tra OTP còn hạn, đúng → đổi password (BCrypt) + mark used + xóa các token cũ cùng email.
 *      → sai quá 5 lần → invalidate token.
 */
@Service
@RequiredArgsConstructor
public class PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);
    private static final int MAX_ATTEMPTS = 5;
    private static final int OTP_TTL_MINUTES = 10;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    /**
     * Tạo OTP + gửi mail. Không bao giờ throw để tránh leak email có/không tồn tại
     * (trả về 200 ở controller bất kể).
     */
    @Transactional
    public void requestReset(String email) {
        String normalized = email.trim().toLowerCase();
        Optional<User> userOpt = userRepository.findByEmail(normalized);
        if (userOpt.isEmpty()) {
            log.info("Forgot-password: email không tồn tại (im lặng trả 200): {}", normalized);
            return;
        }

        // Xóa các OTP cũ của email này để tránh nhầm mã.
        tokenRepository.deleteAllByEmail(normalized);

        String otp = generateOtp();
        String hash = passwordEncoder.encode(otp);

        PasswordResetToken token = PasswordResetToken.builder()
                .email(normalized)
                .otpHash(hash)
                .expiresAt(LocalDateTime.now().plusMinutes(OTP_TTL_MINUTES))
                .attempts(0)
                .used(false)
                .build();
        tokenRepository.save(token);

        emailService.sendPasswordResetOtp(normalized, otp);
    }

    /** Xác minh OTP + đổi mật khẩu. Trả về true nếu thành công. */
    @Transactional
    public void resetPassword(String email, String otp, String newPassword) {
        String normalized = email.trim().toLowerCase();
        PasswordResetToken token = tokenRepository
                .findFirstByEmailAndUsedFalseOrderByCreatedAtDesc(normalized)
                .orElseThrow(() -> new BadRequestException("OTP không hợp lệ hoặc đã hết hạn"));

        if (token.getExpiresAt().isBefore(LocalDateTime.now())) {
            tokenRepository.delete(token);
            throw new BadRequestException("OTP đã hết hạn, vui lòng yêu cầu mã mới");
        }

        if (token.getAttempts() >= MAX_ATTEMPTS) {
            tokenRepository.delete(token);
            throw new BadRequestException("Đã nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới");
        }

        if (!passwordEncoder.matches(otp, token.getOtpHash())) {
            token.setAttempts(token.getAttempts() + 1);
            tokenRepository.save(token);
            throw new BadRequestException(
                    "OTP không đúng (còn " + (MAX_ATTEMPTS - token.getAttempts()) + " lần thử)");
        }

        User user = userRepository.findByEmail(normalized)
                .orElseThrow(() -> new BadRequestException("Tài khoản không tồn tại"));
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        token.setUsed(true);
        tokenRepository.save(token);
        // Xóa hết các token còn lại của email này.
        tokenRepository.deleteAllByEmail(normalized);

        log.info("Password reset thành công cho {}", normalized);
    }

    private static String generateOtp() {
        int n = RANDOM.nextInt(1_000_000);
        return String.format("%06d", n);
    }
}
