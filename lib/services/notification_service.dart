import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/settings_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Reserved ID for daily morning notification
  static const int _dailyMorningId = 99999;

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
      },
    );

    // Request permissions on Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Request permissions on iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedule a daily morning notification at 7:00 AM with the daily budget
  Future<void> scheduleDailyMorningNotification() async {
    // Read daily limit from settings
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();
    final dailyLimit = settings.computedDailyLimit;
    final formatted = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    ).format(dailyLimit);

    // Cancel previous daily notification before rescheduling
    await flutterLocalNotificationsPlugin.cancel(_dailyMorningId);

    // We calculate exactly how much time from 'now' to 7:00 AM using native local time
    final localNow = DateTime.now();
    var targetLocalTime = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      7,
      0,
      0,
    );
    
    if (targetLocalTime.isBefore(localNow)) {
      targetLocalTime = targetLocalTime.add(const Duration(days: 1));
    }

    final durationToWait = targetLocalTime.difference(localNow);
    
    // Add that precise difference to whatever tz.local thinks the current time is (usually UTC)
    var scheduledDate = tz.TZDateTime.now(tz.local).add(durationToWait);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _dailyMorningId,
      'Chào buổi sáng! ☀️',
      'Hôm nay ví bạn có $formatted để tiêu xài. Cà phê nhẹ nhàng thôi nhé!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_morning_channel_v3',
          'Lời nhắc buổi sáng',
          channelDescription: 'Thông báo ngân sách hàng ngày mỗi buổi sáng',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    int? monthOfYear,
    bool isYearly = false,
    int interval = 1,
    DateTime? specificDate,
  }) async {
    // Generate the exact target date using native device LOCAL time
    final targetLocalTime = specificDate ?? _nextInstanceLocal(dayOfMonth, monthOfYear, isYearly);

    final localNow = DateTime.now();
    final durationToWait = targetLocalTime.difference(localNow);
    
    // Add that precise difference to whatever tz.local thinks the current time is (usually UTC)
    final scheduledDate = tz.TZDateTime.now(tz.local).add(durationToWait);

    final matchComponents = (interval == 1)
        ? (isYearly
              ? DateTimeComponents.dateAndTime
              : DateTimeComponents.dayOfMonthAndTime)
        : null;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_channel_v2', // Bumped ID to bypass old cached system rules
          'Thanh toán định kỳ',
          channelDescription: 'Nhắc nhở thanh toán hóa đơn định kỳ',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
    );
  }

  DateTime _nextInstanceLocal(int day, int? month, bool isYearly) {
    final now = DateTime.now();

    // Schedule for 9:00 AM local time
    if (isYearly && month != null) {
      DateTime scheduledDate = DateTime(
        now.year,
        month,
        day,
        9,
        0,
        0,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = DateTime(
          now.year + 1,
          month,
          day,
          9,
          0,
          0,
        );
      }
      return scheduledDate;
    } else {
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        day,
        9,
        0,
        0,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        if (scheduledDate.day != day || scheduledDate.month == now.month) {
          int nextMonth = now.month + 1;
          int nextYear = now.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear = now.year + 1;
          }
          scheduledDate = DateTime(
            nextYear,
            nextMonth,
            day,
            9,
            0,
            0,
          );
        }
      }
      return scheduledDate;
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
