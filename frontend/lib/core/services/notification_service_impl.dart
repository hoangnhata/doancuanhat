import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1;
  static const int _testReminderId = 997;

  static Future<void> init() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onSelect,
    );

    const androidChannel = AndroidNotificationChannel(
      'expense_reminder',
      'Nhắc nhở chi tiêu',
      description: 'Nhắc ghi chép chi tiêu và cảnh báo ngân sách',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static void _onSelect(NotificationResponse? response) {}

  /// Android: tin [AndroidFlutterLocalNotificationsPlugin.areNotificationsEnabled] (đồng bộ với
  /// POST_NOTIFICATIONS / trạng thái thật). Một số máy + [permission_handler] báo sai sau khi đã cấp quyền.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        Future<bool> systemAllowsPosting() async {
          final v = await android.areNotificationsEnabled();
          return v == true;
        }

        if (await systemAllowsPosting()) return true;

        await android.requestNotificationsPermission();

        // Sau khi user bấm Cho phép, có ROM cập nhật chậm — poll ngắn rồi mới kết luận.
        for (var i = 0; i < 12; i++) {
          if (await systemAllowsPosting()) return true;
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }

        // Dự phòng: permission_handler (nếu khớp với hệ thống).
        var status = await Permission.notification.status;
        if (status.isGranted) return true;
        status = await Permission.notification.request().timeout(const Duration(seconds: 45));
        return status.isGranted || await systemAllowsPosting();
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
        if (granted == true) return true;
        final opts = await ios.checkPermissions();
        return opts?.isEnabled == true;
      }

      var status = await Permission.notification.status;
      if (status.isGranted) return true;
      status = await Permission.notification.request().timeout(const Duration(seconds: 45));
      return status.isGranted;
    } catch (_) {
      try {
        final android =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final v = await android?.areNotificationsEnabled();
        if (v == true) return true;
        final s = await Permission.notification.status;
        return s.isGranted;
      } catch (_) {
        return false;
      }
    }
  }

  /// Android 12+ (API 31+): lịch đúng phút cần `canScheduleExactAlarms`. Mở màn hình cài đặt nếu chưa bật.
  /// Trả về true ngay trên iOS / Android cũ / máy đã được phép.
  static Future<bool> ensureAndroidExactAlarmsIfNeeded() async {
    if (kIsWeb) return true;

    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    try {
      var can = await android.canScheduleExactNotifications();
      if (can == true) return true;

      final granted = await android.requestExactAlarmsPermission();
      if (granted == true) return true;

      can = await android.canScheduleExactNotifications();
      return can == true;
    } catch (_) {
      final can = await android.canScheduleExactNotifications();
      return can == true;
    }
  }

  static NotificationDetails _details({String? channelDesc}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'expense_reminder',
        'Nhắc nhở chi tiêu',
        channelDescription: channelDesc ?? 'Nhắc ghi chép chi tiêu theo giờ bạn chọn',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Lặp mỗi ngày đúng [hour]:[minute] theo múi giờ local đã set trong [init] (ưu tiên giờ máy).
  static Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    if (kIsWeb) return;

    await _plugin.cancel(_dailyReminderId);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // So sánh theo phút: tránh lệch vài giây làm lịch nhảy sang ngày mai khi vẫn đang trong đúng phút đặt.
    final nowKey = now.hour * 60 + now.minute;
    final slotKey = hour * 60 + minute;
    if (slotKey < nowKey || (slotKey == nowKey && scheduled.isBefore(now))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    // Đúng giờ–phút: cần quyền báo thức chính xác trên Android 12+ ([ensureAndroidExactAlarmsIfNeeded]).
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Nhắc nhở chi tiêu',
      'Đừng quên ghi chép chi tiêu hôm nay nhé!',
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  static Future<void> showTestReminderNow() async {
    if (kIsWeb) return;
    await _plugin.show(
      _testReminderId,
      'Nhắc nhở chi tiêu',
      'Đây là thông báo thử — lịch hàng ngày vẫn theo giờ bạn đã đặt.',
      _details(channelDesc: 'Thử thông báo'),
    );
  }

  static Future<void> showBudgetWarning(String categoryName, double usedPercent) async {
    if (kIsWeb) return;
    await _plugin.show(
      2,
      'Cảnh báo ngân sách',
      'Danh mục "$categoryName" đã sử dụng ${usedPercent.toStringAsFixed(0)}% ngân sách',
      _details(channelDesc: 'Cảnh báo khi sắp vượt ngân sách'),
    );
  }
}
