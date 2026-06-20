import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/core/di/injection.dart';
import 'package:expense_manager/domain/models/user.dart';
import 'package:expense_manager/domain/repositories/auth_repository.dart';
import 'package:expense_manager/domain/repositories/user_repository.dart';
import 'package:expense_manager/domain/repositories/transaction_repository.dart';
import 'package:expense_manager/domain/repositories/category_repository.dart';
import 'package:expense_manager/domain/repositories/budget_repository.dart';
import 'package:expense_manager/domain/repositories/statistics_repository.dart';
import 'package:expense_manager/domain/repositories/recurring_transaction_repository.dart';
import 'package:expense_manager/domain/repositories/wallet_repository.dart';
import 'package:expense_manager/domain/repositories/saving_goal_repository.dart';
import 'package:expense_manager/domain/repositories/spending_limit_repository.dart';
import 'package:expense_manager/data/repositories/export_repository_impl.dart';
import 'package:expense_manager/data/sync/sync_service.dart';
import 'package:expense_manager/core/services/notification_service.dart';

final currentUserProvider = FutureProvider<User?>((ref) => localStorage.getUser());

/// Đồng bộ SQLite ↔ server (MySQL qua REST). Gọi trước khi đọc dữ liệu để khớp với web.
final syncServiceProvider = Provider<SyncService>((ref) => syncService);

final authRepositoryProvider = Provider<AuthRepository>((ref) => authRepository);
final userRepositoryProvider = Provider<UserRepository>((ref) => userRepository);
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) => transactionRepository);
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => categoryRepository);
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => budgetRepository);
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) => statisticsRepository);
final exportRepositoryProvider = Provider<ExportRepository>((ref) => exportRepository);
final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) => recurringTransactionRepository);
final walletRepositoryProvider = Provider<WalletRepository>((ref) => walletRepository);
final savingGoalRepositoryProvider = Provider<SavingGoalRepository>((ref) => savingGoalRepository);
final spendingLimitRepositoryProvider = Provider<SpendingLimitRepository>((ref) => spendingLimitRepository);

final selectedWalletIdProvider = StateProvider<int?>((ref) => null);

/// Theme mode (Light / Dark / System) — lưu vào SharedPreferences.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initial());

  static ThemeMode _initial() {
    switch (localStorage.readThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await localStorage.setThemeMode(s);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Tăng giá trị sau khi thêm/sửa giao dịch để [TransactionsTab] tự gọi API lại
/// (IndexedStack giữ tab sống nên không có `.then` ở MainScreen FAB thì list không refresh).
final transactionListRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Giờ nhắc + trạng thái bật/tắt (lưu SharedPreferences, đăng ký flutter_local_notifications).
class DailyReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const DailyReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  DailyReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return DailyReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

final dailyReminderProvider =
    StateNotifierProvider<DailyReminderNotifier, DailyReminderSettings>((ref) => DailyReminderNotifier());

/// Kết quả bật nhắc (để hiển thị SnackBar đúng nội dung).
enum DailyReminderEnableFailure {
  notificationPermission,
  exactAlarmPermission,
  scheduleFailed,
}

class DailyReminderEnableResult {
  final bool ok;
  final DailyReminderEnableFailure? failure;

  const DailyReminderEnableResult._({required this.ok, this.failure});

  factory DailyReminderEnableResult.success() =>
      const DailyReminderEnableResult._(ok: true, failure: null);

  factory DailyReminderEnableResult.failure(DailyReminderEnableFailure f) =>
      DailyReminderEnableResult._(ok: false, failure: f);
}

class DailyReminderNotifier extends StateNotifier<DailyReminderSettings> {
  DailyReminderNotifier() : super(_readPrefsFromStorage());

  static DailyReminderSettings _readPrefsFromStorage() {
    final p = localStorage.readDailyReminderPrefs();
    return DailyReminderSettings(enabled: p.enabled, hour: p.hour, minute: p.minute);
  }

  /// Bật nhắc: quyền thông báo + (Android 12+) quyền báo thức chính xác để đúng giờ–phút.
  Future<DailyReminderEnableResult> setEnabled(bool value) async {
    if (!value) {
      await localStorage.setDailyReminderEnabled(false);
      await NotificationService.cancelDailyReminder();
      state = state.copyWith(enabled: false);
      return DailyReminderEnableResult.success();
    }
    // Bật ngay trên UI — tránh cảm giác “không nhấn được” khi chờ hộp thoại hệ thống.
    state = state.copyWith(enabled: true);
    try {
      final ok = await NotificationService.requestPermission();
      if (!ok) {
        await localStorage.setDailyReminderEnabled(false);
        await NotificationService.cancelDailyReminder();
        state = state.copyWith(enabled: false);
        return DailyReminderEnableResult.failure(DailyReminderEnableFailure.notificationPermission);
      }
      final exactOk = await NotificationService.ensureAndroidExactAlarmsIfNeeded();
      if (!exactOk) {
        await localStorage.setDailyReminderEnabled(false);
        await NotificationService.cancelDailyReminder();
        state = state.copyWith(enabled: false);
        return DailyReminderEnableResult.failure(DailyReminderEnableFailure.exactAlarmPermission);
      }
      final hour = await localStorage.getDailyReminderHour();
      final minute = await localStorage.getDailyReminderMinute();
      await localStorage.setDailyReminderEnabled(true);
      await NotificationService.scheduleDailyReminder(hour: hour, minute: minute);
      state = DailyReminderSettings(enabled: true, hour: hour, minute: minute);
      return DailyReminderEnableResult.success();
    } catch (_) {
      await localStorage.setDailyReminderEnabled(false);
      await NotificationService.cancelDailyReminder();
      state = state.copyWith(enabled: false);
      return DailyReminderEnableResult.failure(DailyReminderEnableFailure.scheduleFailed);
    }
  }

  Future<void> setTime(int hour, int minute) async {
    await localStorage.setDailyReminderHour(hour);
    await localStorage.setDailyReminderMinute(minute);
    state = state.copyWith(hour: hour, minute: minute);
    if (state.enabled) {
      if (await NotificationService.ensureAndroidExactAlarmsIfNeeded()) {
        await NotificationService.scheduleDailyReminder(hour: hour, minute: minute);
      }
    }
  }

  Future<void> sendTestNow() async {
    await NotificationService.requestPermission();
    await NotificationService.showTestReminderNow();
  }
}
