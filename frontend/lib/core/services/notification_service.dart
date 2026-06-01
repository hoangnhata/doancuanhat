import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_impl.dart' as impl;

class NotificationService {
  static Future<void> init() => impl.NotificationService.init();
  static Future<bool> requestPermission() => impl.NotificationService.requestPermission();
  /// Android 12+: bắt buộc để lịch nhắc đúng từng phút ([exactAllowWhileIdle]). iOS/Web: luôn true.
  static Future<bool> ensureAndroidExactAlarmsIfNeeded() =>
      impl.NotificationService.ensureAndroidExactAlarmsIfNeeded();
  static Future<void> scheduleDailyReminder({required int hour, required int minute}) =>
      impl.NotificationService.scheduleDailyReminder(hour: hour, minute: minute);
  static Future<void> cancelDailyReminder() => impl.NotificationService.cancelDailyReminder();
  /// Hiển thị ngay một thông báo để kiểm tra quyền / kênh (không đổi lịch hàng ngày).
  static Future<void> showTestReminderNow() => impl.NotificationService.showTestReminderNow();
  static Future<void> showBudgetWarning(String categoryName, double usedPercent) =>
      impl.NotificationService.showBudgetWarning(categoryName, usedPercent);
}
