package com.expense.service;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.Optional;

/**
 * Gửi email **bất đồng bộ** (chạy trên thread pool "mailExecutor") — tránh block request handler.
 * JavaMailSender.send() qua SMTP thật (Gmail) có thể mất 5-30s nên BẮT BUỘC phải async,
 * nếu không client sẽ timeout dù DB đã lưu xong.
 *
 * Vì @Async chỉ hoạt động qua Spring proxy → method này nằm ở class khác (không tự gọi).
 */
@Service
@RequiredArgsConstructor
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final Optional<JavaMailSender> mailSender;

    @Value("${spring.mail.username:}")
    private String mailFrom;

    @Value("${app.password-reset.dev-log-otp:true}")
    private boolean devLogOtp;

    /** Gửi OTP đăng ký (async — không block API). */
    @Async("mailExecutor")
    public void sendRegistrationOtp(String email, String otp, String fullName) {
        send(
            email,
            "[Natta AI] Xác minh đăng ký tài khoản",
            "Chào " + (fullName == null || fullName.isBlank() ? "bạn" : fullName) + ",\n\n"
                + "Cảm ơn bạn đã đăng ký Natta AI Expense Manager.\n"
                + "Mã OTP xác minh email của bạn là: " + otp + "\n"
                + "Mã có hiệu lực trong 10 phút.\n\n"
                + "Nếu không phải bạn thực hiện, hãy bỏ qua email này.\n\n"
                + "— Natta AI Expense Manager",
            otp,
            "đăng ký"
        );
    }

    /** Gửi OTP reset password (async). */
    @Async("mailExecutor")
    public void sendPasswordResetOtp(String email, String otp) {
        send(
            email,
            "[Natta AI] Mã đặt lại mật khẩu",
            "Xin chào,\n\n"
                + "Mã OTP đặt lại mật khẩu của bạn là: " + otp + "\n"
                + "Mã có hiệu lực trong 10 phút.\n\n"
                + "Nếu không phải bạn yêu cầu, hãy bỏ qua email này.\n\n"
                + "— Natta AI Expense Manager",
            otp,
            "reset password"
        );
    }

    private void send(String email, String subject, String body, String otp, String kind) {
        if (mailSender.isEmpty()) {
            if (devLogOtp) {
                log.warn("[DEV] OTP {} cho {} = {} (chua cau hinh spring.mail.* nen khong gui mail that)", kind, email, otp);
            }
            return;
        }
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            if (mailFrom != null && !mailFrom.isBlank()) {
                msg.setFrom(mailFrom);
            }
            msg.setTo(email);
            msg.setSubject(subject);
            msg.setText(body);
            mailSender.get().send(msg);
            log.info("Da gui OTP {} den {}", kind, email);
        } catch (Exception ex) {
            log.warn("Gui mail OTP {} that bai ({}). OTP={}", kind, ex.getMessage(), otp);
            if (devLogOtp) {
                log.warn("[DEV-FALLBACK] OTP {} {} = {}", kind, email, otp);
            }
        }
    }
}
