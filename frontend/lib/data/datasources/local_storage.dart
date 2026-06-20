import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_manager/core/constants/storage_constants.dart';
import 'package:expense_manager/domain/models/user.dart';

class LocalStorage {
  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _prefs.setString(StorageConstants.accessToken, accessToken);
    await _prefs.setString(StorageConstants.refreshToken, refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _prefs.getString(StorageConstants.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return _prefs.getString(StorageConstants.refreshToken);
  }

  Future<void> saveUser(User user) async {
    await _prefs.setString(StorageConstants.userData, jsonEncode({
      'id': user.id,
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'botPersonality': user.botPersonality,
      'botSetupCompleted': user.botSetupCompleted,
      'onboardingCompleted': user.onboardingCompleted,
      'walletSetupCompleted': user.walletSetupCompleted,
      'savingGoalSetupCompleted': user.savingGoalSetupCompleted,
      'savingGoalSetupSkipped': user.savingGoalSetupSkipped,
      'spendingLimitSetupCompleted': user.spendingLimitSetupCompleted,
      'spendingLimitSetupSkipped': user.spendingLimitSetupSkipped,
      'onboardingStep': user.onboardingStep,
      'walletName': user.walletName,
      'currencyCode': user.currencyCode,
      'initialBalance': user.initialBalance,
    }));
  }

  Future<User?> getUser() async {
    final json = _prefs.getString(StorageConstants.userData);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final initBal = map['initialBalance'];
      return User(
        id: map['id'] as int,
        fullName: map['fullName'] as String,
        email: map['email'] as String,
        phone: map['phone'] as String?,
        botPersonality: map['botPersonality'] as String?,
        botSetupCompleted: map['botSetupCompleted'] as bool? ?? false,
        onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
        walletSetupCompleted: map['walletSetupCompleted'] as bool? ?? false,
        savingGoalSetupCompleted: map['savingGoalSetupCompleted'] as bool? ?? false,
        savingGoalSetupSkipped: map['savingGoalSetupSkipped'] as bool? ?? false,
        spendingLimitSetupCompleted: map['spendingLimitSetupCompleted'] as bool? ?? false,
        spendingLimitSetupSkipped: map['spendingLimitSetupSkipped'] as bool? ?? false,
        onboardingStep: map['onboardingStep'] as String?,
        walletName: map['walletName'] as String?,
        currencyCode: map['currencyCode'] as String?,
      initialBalance: initBal != null ? (initBal is num ? initBal.toDouble() : double.tryParse(initBal.toString())) : null,
    );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _prefs.remove(StorageConstants.accessToken);
    await _prefs.remove(StorageConstants.refreshToken);
    await _prefs.remove(StorageConstants.userData);
    await _prefs.remove(StorageConstants.onboardingCompleted);
    await _prefs.remove(StorageConstants.dailyReminderEnabled);
    await _prefs.remove(StorageConstants.dailyReminderHour);
    await _prefs.remove(StorageConstants.dailyReminderMinute);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    if (token == null) return false;
    if (_isJwtExpired(token)) {
      await clearAuth();
      return false;
    }
    return true;
  }

  /// Xóa thông tin đăng nhập (token + user) nhưng giữ các setting khác.
  Future<void> clearAuth() async {
    await _prefs.remove(StorageConstants.accessToken);
    await _prefs.remove(StorageConstants.refreshToken);
    await _prefs.remove(StorageConstants.userData);
  }

  Future<void> setDailyReminderEnabled(bool value) async {
    await _prefs.setBool(StorageConstants.dailyReminderEnabled, value);
  }

  Future<bool> isDailyReminderEnabled() async {
    return _prefs.getBool(StorageConstants.dailyReminderEnabled) ?? false;
  }

  Future<int> getDailyReminderHour() async {
    return _prefs.getInt(StorageConstants.dailyReminderHour) ?? 21;
  }

  Future<int> getDailyReminderMinute() async {
    return _prefs.getInt(StorageConstants.dailyReminderMinute) ?? 0;
  }

  Future<void> setDailyReminderHour(int hour) async {
    await _prefs.setInt(StorageConstants.dailyReminderHour, hour.clamp(0, 23));
  }

  Future<void> setDailyReminderMinute(int minute) async {
    await _prefs.setInt(StorageConstants.dailyReminderMinute, minute.clamp(0, 59));
  }

  /// Theme mode: 'light' | 'dark' | 'system' (mặc định 'system').
  String readThemeMode() {
    return _prefs.getString(StorageConstants.themeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(StorageConstants.themeMode, mode);
  }

  /// Đọc đồng bộ (prefs đã load sau [initDependencies]) — tránh race `_load` async làm Switch “đơ”.
  ({bool enabled, int hour, int minute}) readDailyReminderPrefs() {
    return (
      enabled: _prefs.getBool(StorageConstants.dailyReminderEnabled) ?? false,
      hour: (_prefs.getInt(StorageConstants.dailyReminderHour) ?? 21).clamp(0, 23),
      minute: (_prefs.getInt(StorageConstants.dailyReminderMinute) ?? 0).clamp(0, 59),
    );
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) return true;
      final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
      // Trừ một chút skew để tránh sát giây bị coi là còn hạn.
      return nowSec >= (exp.toDouble() - 10);
    } catch (_) {
      return true;
    }
  }
}
