import 'package:expense_manager/core/constants/api_constants.dart';
import 'package:expense_manager/data/datasources/api_client.dart';
import 'package:expense_manager/data/datasources/local_storage.dart';
import 'package:expense_manager/data/local/database.dart';
import 'package:expense_manager/domain/models/user.dart';
import 'package:expense_manager/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  final LocalStorage _storage;
  final AppDatabase _db;

  AuthRepositoryImpl(this._api, this._storage, this._db);

  @override
  Future<AuthResult> register(String fullName, String email, String password, {String? phone}) async {
    final response = await _api.post(ApiConstants.authRegister, data: {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
    });
    return await _parseAuthResponse(response);
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    final response = await _api.post(ApiConstants.authLogin, data: {
      'email': email,
      'password': password,
    });
    return await _parseAuthResponse(response);
  }

  Future<AuthResult> _parseAuthResponse(Map<String, dynamic> response) async {
    final data = response['data'] as Map<String, dynamic>;
    final userData = data['user'] as Map<String, dynamic>;
    final newUserId = userData['id'] as int;

    /// SQLite không gắn với userId trong bảng — khi đổi tài khoản (đăng ký mới / đăng nhập user khác)
    /// hoặc session trước bị clearAuth (JWT hết hạn) mà DB chưa dọn, ví local cũ (vd. demo AI) vẫn còn
    /// và sync chỉ xóa ví remoteId=null → app hiện 2 ví trong khi server chỉ có 1.
    final previous = await _storage.getUser();
    if (previous == null || previous.id != newUserId) {
      await _db.clearAllData();
    }

    final initBal = userData['initialBalance'];
    final savingsGoal = userData['savingsGoalMonthly'];
    final user = User(
      id: userData['id'] as int,
      fullName: userData['fullName'] as String,
      email: userData['email'] as String,
      phone: userData['phone'] as String?,
      botPersonality: userData['botPersonality'] as String?,
      onboardingCompleted: userData['onboardingCompleted'] as bool? ?? false,
      walletName: userData['walletName'] as String?,
      currencyCode: userData['currencyCode'] as String?,
      initialBalance: initBal != null ? (initBal is num ? initBal.toDouble() : double.tryParse(initBal.toString())) : null,
      savingsGoalMonthly: savingsGoal != null ? (savingsGoal is num ? savingsGoal.toDouble() : double.tryParse(savingsGoal.toString())) : null,
    );

    await _storage.saveTokens(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    await _storage.saveUser(user);

    return AuthResult(user: user, accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
  }

  @override
  Future<void> logout() async {
    await _storage.clearAll();
    await _db.clearAllData();
  }

  @override
  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.post(ApiConstants.authForgotPassword, data: {'email': email.trim()});
  }

  @override
  Future<void> resetPassword({required String email, required String otp, required String newPassword}) async {
    await _api.post(ApiConstants.authResetPassword, data: {
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> requestRegistration({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _api.post(ApiConstants.authRegisterRequest, data: {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  @override
  Future<AuthResult> verifyRegistration({required String email, required String otp}) async {
    final response = await _api.post(ApiConstants.authRegisterVerify, data: {
      'email': email.trim(),
      'otp': otp.trim(),
    });
    return _parseAuthResponse(response);
  }

  @override
  Future<void> resendRegistrationOtp(String email) async {
    await _api.post(ApiConstants.authRegisterResendOtp, data: {'email': email.trim()});
  }
}
