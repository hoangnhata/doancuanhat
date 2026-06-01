import 'package:expense_manager/domain/models/user.dart';

abstract class AuthRepository {
  Future<AuthResult> register(String fullName, String email, String password, {String? phone});
  Future<AuthResult> login(String email, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({required String email, required String otp, required String newPassword});

  /// Bước 1 đăng ký OTP: gửi thông tin lên server, server sẽ gửi OTP qua email.
  Future<void> requestRegistration({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });

  /// Bước 2 đăng ký OTP: nhập OTP → tạo user thật + auto-login.
  Future<AuthResult> verifyRegistration({required String email, required String otp});

  /// Gửi lại OTP cho yêu cầu đăng ký pending.
  Future<void> resendRegistrationOtp(String email);
}

class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}
