class NotificationService {
  static Future<void> init() async {}
  static Future<bool> requestPermission() async => false;
  static Future<bool> ensureAndroidExactAlarmsIfNeeded() async => true;
  static Future<void> scheduleDailyReminder({required int hour, required int minute}) async {}
  static Future<void> cancelDailyReminder() async {}
  static Future<void> showTestReminderNow() async {}
  static Future<void> showBudgetWarning(String categoryName, double usedPercent) async {}
}
