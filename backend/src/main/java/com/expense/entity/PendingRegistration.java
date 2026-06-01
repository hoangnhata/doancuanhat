package com.expense.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Yêu cầu đăng ký chờ verify OTP. KHÔNG tạo user thật trong bảng `users` cho đến khi
 * user nhập đúng OTP — tránh tạo tài khoản từ email không có thật.
 */
@Entity
@Table(name = "pending_registrations", indexes = {
        @Index(name = "idx_pending_reg_email", columnList = "email"),
        @Index(name = "idx_pending_reg_expires_at", columnList = "expires_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PendingRegistration {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String email;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    /** Password đã BCrypt-hash (giữ giống User.password để re-use khi tạo user thật). */
    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(length = 20)
    private String phone;

    /** OTP đã hash bằng BCrypt (không lưu plain). */
    @Column(name = "otp_hash", nullable = false, length = 100)
    private String otpHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    /** Số lần verify sai — chặn brute-force OTP 6 số. */
    @Column(nullable = false)
    @Builder.Default
    private Integer attempts = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
