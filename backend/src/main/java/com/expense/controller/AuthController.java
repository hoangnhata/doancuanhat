package com.expense.controller;

import com.expense.dto.auth.AuthResponse;
import com.expense.dto.auth.ForgotPasswordRequest;
import com.expense.dto.auth.LoginRequest;
import com.expense.dto.auth.RegisterRequest;
import com.expense.dto.auth.ResetPasswordRequest;
import com.expense.dto.auth.VerifyRegistrationRequest;
import com.expense.dto.common.ApiResponse;
import com.expense.security.JwtTokenProvider;
import com.expense.service.AuthService;
import com.expense.service.PasswordResetService;
import com.expense.service.PendingRegistrationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final JwtTokenProvider tokenProvider;
    private final PasswordResetService passwordResetService;
    private final PendingRegistrationService pendingRegistrationService;

    /**
     * Đăng ký truyền thống (không OTP) — giữ cho tương thích client cũ.
     * KHUYẾN NGHỊ dùng /auth/register/request + /auth/register/verify để xác minh email trước.
     */
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.ok(ApiResponse.success("Registration successful", response));
    }

    /**
     * Bước 1 đăng ký 2 bước: nhận thông tin + gửi OTP về email.
     * Chưa tạo user thật trong bảng users cho đến khi verify thành công.
     */
    @PostMapping("/register/request")
    public ResponseEntity<ApiResponse<Void>> requestRegister(@Valid @RequestBody RegisterRequest request) {
        pendingRegistrationService.requestRegistration(request);
        return ResponseEntity.ok(ApiResponse.success(
                "Đã gửi mã OTP đến email. Vui lòng nhập mã để hoàn tất đăng ký.", null));
    }

    /** Bước 2 đăng ký 2 bước: verify OTP → tạo user thật + trả token (auto-login). */
    @PostMapping("/register/verify")
    public ResponseEntity<ApiResponse<AuthResponse>> verifyRegister(@Valid @RequestBody VerifyRegistrationRequest request) {
        AuthResponse response = pendingRegistrationService.verifyAndCreateUser(request.getEmail(), request.getOtp());
        return ResponseEntity.ok(ApiResponse.success("Đăng ký thành công", response));
    }

    /** Gửi lại OTP cho yêu cầu đăng ký đang pending. */
    @PostMapping("/register/resend-otp")
    public ResponseEntity<ApiResponse<Void>> resendRegisterOtp(@Valid @RequestBody ForgotPasswordRequest request) {
        pendingRegistrationService.resendOtp(request.getEmail());
        return ResponseEntity.ok(ApiResponse.success("Đã gửi lại OTP đăng ký", null));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.success("Login successful", response));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(@RequestHeader("Authorization") String authHeader) {
        String token = authHeader != null && authHeader.startsWith("Bearer ") ? authHeader.substring(7) : null;
        if (token == null || !tokenProvider.validateToken(token)) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Invalid or expired token"));
        }
        String email = tokenProvider.getEmailFromToken(token);
        AuthResponse response = authService.refreshToken(email);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Yêu cầu OTP đặt lại mật khẩu. Luôn trả 200 dù email tồn tại hay không
     * (tránh leak danh sách email cho attacker).
     */
    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        passwordResetService.requestReset(request.getEmail());
        return ResponseEntity.ok(ApiResponse.success(
                "Nếu email tồn tại, mã OTP đã được gửi. Vui lòng kiểm tra hộp thư.", null));
    }

    /** Đổi mật khẩu bằng OTP. */
    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<Void>> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        passwordResetService.resetPassword(request.getEmail(), request.getOtp(), request.getNewPassword());
        return ResponseEntity.ok(ApiResponse.success("Đã đặt lại mật khẩu thành công", null));
    }
}
