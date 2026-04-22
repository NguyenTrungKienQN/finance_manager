import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/debt_record_model.dart';
import '../models/habit_breaker_model.dart';
import '../models/savings_goal_model.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';
import 'app_time_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyMorningId = 99999;
  static const int _eveningSummaryId = 99998;
  static const int _weeklyInsightId = 99997;
  static const int _habitBaseId = 99990;
  static const int _habitMaxCount = 6;
  static const int _debtBaseId = 99980;
  static const int _debtMaxCount = 10;
  static const int _endOfMonthId = 99970;
  static const int _overspendWarningId = 99966;
  static const int _overspendCriticalId = 99967;
  static const int _savingsMilestoneId = 99968;
  static const int _streakFrozenId = 99969;
  static const int _streakRecoveredId = 99965;
  static const int _velocityWarningId = 99964;

  static const String _sentLogKey = 'sent_notifications';
  static const String _plannedLogKey = 'planned_notifications';
  static const String _overspendHistoryKey = 'overspend_history';
  static const String _velocityHistoryKey = 'velocity_history';
  static const String _categoryThresholdHistoryKey =
      'category_threshold_history';

  static const int _priorityMorningBudget = 90;
  static const int _priorityOverspendAlert = 100;
  static const int _priorityHabitStreak = 80;
  static const int _priorityEveningSummary = 30;
  static const int _priorityWeeklyInsight = 20;
  static const int _priorityDebtReminder = 40;
  static const int _priorityEndOfMonth = 35;
  static const int _prioritySavingsMilestone = 50;
  static const int _maxNotificationsPerDay = 3;

  Future<void> init() async {
    tz.initializeTimeZones();

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    final initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {},
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _createAndroidChannels();
  }

  Future<void> scheduleAllSmartNotifications() async {
    await _createAndroidChannels();
    await _cancelSmartScheduledNotifications();
    await _clearSmartPlannedNotifications();

    final settings = _settings;
    final candidates = <_ScheduledCandidate>[];

    if (settings.notifMorningBudget) {
      candidates.add(_buildMorningBudgetCandidate(settings));
    }

    if (settings.notifHabitStreak) {
      candidates.addAll(_buildHabitCandidates());
    }

    if (settings.notifEveningSummary) {
      candidates.add(_buildEveningSummaryCandidate());
    }

    if (settings.notifWeeklyInsight) {
      candidates.add(_buildWeeklyInsightCandidate());
    }

    if (settings.notifDebtReminder) {
      candidates.addAll(_buildDebtReminderCandidates());
    }

    if (settings.notifEndOfMonth) {
      final candidate = _buildEndOfMonthCandidate();
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    candidates.sort((left, right) {
      final byDate = left.scheduledAt.compareTo(right.scheduledAt);
      if (byDate != 0) return byDate;
      return right.priority.compareTo(left.priority);
    });

    for (final candidate in candidates) {
      await _scheduleCandidate(candidate);
    }
  }

  Future<void> fireOverspendAlert({
    required double spentAmount,
    required double dailyLimit,
  }) async {
    final settings = _settings;
    if (!settings.notifOverspendAlert || dailyLimit <= 0) return;

    final ratio = spentAmount / dailyLimit;
    if (ratio < 0.8) return;

    final level = ratio >= 1 ? 'critical' : 'warning';
    final history = _overspendHistory;
    final todayKey = _dayKey(AppTimeService.instance.now());
    final historyKey = '$todayKey:$level';
    if (history.contains(historyKey)) return;

    final allowed = await _canSendNotification(
      priority: _priorityOverspendAlert,
    );
    if (!allowed) return;

    final title = ratio >= 1 ? 'Vượt hạn mức! 🔥' : 'Sắp vượt hạn mức! ⚠️';
    final body = ratio >= 1
        ? 'Bạn đã vượt quá ngân sách hôm nay. Dừng lại một nhịp trước giao dịch tiếp theo.'
        : 'Bạn đã dùng ${(ratio * 100).round()}% ngân sách hôm nay. Cẩn thận giao dịch tiếp theo.';

    await flutterLocalNotificationsPlugin.show(
      ratio >= 1 ? _overspendCriticalId : _overspendWarningId,
      title,
      body,
      _notificationDetails(
        androidChannelId: 'overspend_alerts',
        androidChannelName: 'Cảnh báo vượt chi',
        androidChannelDescription: 'Cảnh báo chi tiêu sắp hoặc đã vượt hạn mức',
      ),
    );

    await _logNotificationSent(
      id: ratio >= 1 ? _overspendCriticalId : _overspendWarningId,
      priority: _priorityOverspendAlert,
    );
    history.add(historyKey);
    await _notificationLogBox.put(_overspendHistoryKey, history);
  }

  Future<void> fireVelocityWarning({
    required String category,
    required int daysEarly,
    required DateTime exhaustionDate,
  }) async {
    final settings = _settings;
    // Tie to overspend alerts toggle for now
    if (!settings.notifOverspendAlert || daysEarly < 3) return;

    final history = _velocityHistory;
    final todayKey = _dayKey(AppTimeService.instance.now());
    final historyKey = '$todayKey:$category';
    if (history.contains(historyKey)) return;

    final allowed = await _canSendNotification(
      priority: _priorityOverspendAlert,
    );
    if (!allowed) return;

    final title = 'Cảnh báo tốc độ chi tiêu 📉';
    final dateStr = DateFormat('dd/MM').format(exhaustionDate);
    final body =
        'Tốc độ chi tiêu nhóm "$category" đang quá nhanh. Dự kiến cạn kiệt ngân sách vào $dateStr (sớm $daysEarly ngày).';

    await flutterLocalNotificationsPlugin.show(
      _velocityWarningId,
      title,
      body,
      _notificationDetails(
        androidChannelId: 'velocity_alerts',
        androidChannelName: 'Cảnh báo tốc độ chi',
        androidChannelDescription:
            'Cảnh báo khi tốc độ chi tiêu dự kiến vượt hạn mức sớm',
      ),
    );

    await _logNotificationSent(
      id: _velocityWarningId,
      priority: _priorityOverspendAlert,
    );
    history.add(historyKey);
    await _notificationLogBox.put(_velocityHistoryKey, history);
  }

  Future<void> fireSavingsGoalMilestone(SavingsGoal goal) async {
    final settings = _settings;
    if (!settings.notifSavingsMilestone || !goal.isCompleted) return;

    final allowed = await _canSendNotification(
      priority: _prioritySavingsMilestone,
    );
    if (!allowed) return;

    await flutterLocalNotificationsPlugin.show(
      _savingsMilestoneId,
      'Mục tiêu tiết kiệm đã hoàn thành! 🎯',
      'Bạn vừa hoàn thành hũ "${goal.name}". Nhịp này rất tốt.',
      _notificationDetails(
        androidChannelId: 'savings_milestones',
        androidChannelName: 'Mốc tiết kiệm',
        androidChannelDescription:
            'Thông báo khi hoàn thành mục tiêu tiết kiệm',
      ),
    );

    await _logNotificationSent(
      id: _savingsMilestoneId,
      priority: _prioritySavingsMilestone,
    );
  }

  Future<void> fireStreakFrozen(HabitBreaker habit) async {
    final settings = _settings;
    if (!settings.notifHabitStreak) return;

    final allowed = await _canSendNotification(
      priority: _priorityHabitStreak,
    );
    if (!allowed) return;

    await flutterLocalNotificationsPlugin.show(
      _streakFrozenId,
      'Chuỗi bị đóng băng! 🧊',
      'Không mua "${habit.habitName}" trong 3 ngày tới để giữ chuỗi hiện tại.',
      _notificationDetails(
        androidChannelId: 'habit_streaks',
        androidChannelName: 'Nhắc chuỗi thói quen',
        androidChannelDescription: 'Thông báo liên quan đến chuỗi bỏ thói quen',
      ),
    );

    await _logNotificationSent(
      id: _streakFrozenId,
      priority: _priorityHabitStreak,
    );
  }

  Future<void> fireCategoryThresholdAlert({
    required String category,
    required double ratio,
  }) async {
    final logBox = Hive.box('notification_log');
    final isEnabled =
        logBox.get('notifCategoryThresholdEnabled', defaultValue: true) as bool;
    if (!isEnabled) return;

    final now = AppTimeService.instance.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final expectedRatio = now.day / daysInMonth;

    // Determine threshold level based on ratio and pacing
    int thresholdPercent;
    if (ratio >= 1.0) {
      thresholdPercent = 100;
    } else if (ratio >= 0.8) {
      thresholdPercent = 80;
    } else if (ratio >= 0.5) {
      // Only warn about 50% if we reached it too quickly (e.g. before 40% of the month)
      // If it's late in the month, 50% spent is actually healthy pacing.
      if (expectedRatio < 0.4) {
        thresholdPercent = 50;
      } else {
        return; // Suppress false-positive warning
      }
    } else {
      return;
    }

    final history = _categoryThresholdHistory;
    final monthKey = '${now.year}-${now.month}';
    final historyKey = '$monthKey:$category:$thresholdPercent';

    if (history.contains(historyKey)) return;

    final allowed = await _canSendNotification(
      priority: _priorityOverspendAlert,
    );
    if (!allowed) return;

    String title;
    String body;
    int id;

    if (thresholdPercent == 100) {
      title = 'Hết ngân sách $category! 🛑';
      body = 'Bạn đã tiêu hết 100% ngân sách cho "$category". Hãy cân nhắc dừng lại.';
      id = 99800 + category.hashCode % 100;
    } else if (thresholdPercent == 80) {
      if (expectedRatio < 0.6) {
        title = 'Tiêu quá nhanh cho $category! ⚠️';
        body = 'Mới qua ${(expectedRatio * 100).round()}% tháng mà đã dùng 80% ngân sách "$category".';
      } else {
        title = 'Sắp hết tiền cho $category! ⚠️';
        body = 'Bạn đã dùng 80% ngân sách cho "$category".';
      }
      id = 99820 + category.hashCode % 100;
    } else {
      title = 'Cảnh báo tốc độ chi $category 💡';
      body = 'Mới đầu tháng mà bạn đã dùng $thresholdPercent% ngân sách cho "$category". Hãy đi chậm lại.';
      id = 99840 + category.hashCode % 100;
    }


    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(
        androidChannelId: 'category_alerts',
        androidChannelName: 'Cảnh báo hạng mục',
        androidChannelDescription:
            'Thông báo khi chi tiêu hạng mục chạm mốc ngân sách',
      ),
    );

    await _logNotificationSent(
      id: id,
      priority: _priorityOverspendAlert,
    );
    history.add(historyKey);
    await _notificationLogBox.put(_categoryThresholdHistoryKey, history);
  }

  Future<void> fireStreakRecovered(HabitBreaker habit) async {
    final settings = _settings;
    if (!settings.notifHabitStreak) return;

    final allowed = await _canSendNotification(
      priority: _priorityHabitStreak,
    );
    if (!allowed) return;

    await flutterLocalNotificationsPlugin.show(
      _streakRecoveredId,
      'Chuỗi đã hồi phục! 💪',
      'Bạn đã cứu thành công chuỗi "${habit.habitName}". Tiếp tục giữ nhịp này.',
      _notificationDetails(
        androidChannelId: 'habit_streaks',
        androidChannelName: 'Nhắc chuỗi thói quen',
        androidChannelDescription: 'Thông báo liên quan đến chuỗi bỏ thói quen',
      ),
    );

    await _logNotificationSent(
      id: _streakRecoveredId,
      priority: _priorityHabitStreak,
    );
  }

  Future<void> scheduleHabitChallengeEncouragements(
    HabitBreaker habit,
    List<String> dailyMessages,
  ) async {
    // Start scheduling from tomorrow morning 8 AM
    final now = AppTimeService.instance.now();

    // We create a unique base ID for this habit to allow cancellation later if needed
    final baseId = 80000 + (habit.id.hashCode % 10000);

    for (int i = 0; i < dailyMessages.length; i++) {
      var startDay = DateTime(now.year, now.month, now.day, 8, 0); // 8 AM
      if (!startDay.isAfter(now)) {
        startDay = startDay.add(const Duration(days: 1));
      }

      final scheduledDate =
          tz.TZDateTime.from(startDay.add(Duration(days: i)), tz.local);

      int dayNum = i + 1;
      String title =
          'Thử thách: ${habit.habitName} (Ngày $dayNum/${dailyMessages.length})';

      await flutterLocalNotificationsPlugin.zonedSchedule(
        baseId + i,
        title,
        dailyMessages[i],
        scheduledDate,
        _notificationDetails(
          androidChannelId: 'habit_streaks',
          androidChannelName: 'Nhắc chuỗi thói quen',
          androidChannelDescription: 'Động viên bỏ thói quen xấu hàng ngày',
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
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
    final targetLocalTime =
        specificDate ?? _nextInstanceLocal(dayOfMonth, monthOfYear, isYearly);

    final localNow = DateTime.now();
    final durationToWait = targetLocalTime.difference(localNow);
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
          'recurring_channel_v2',
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

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  AppSettings get _settings {
    final settingsBox = Hive.box<AppSettings>('settings');
    return settingsBox.get('appSettings') ?? AppSettings();
  }

  Box get _notificationLogBox => Hive.box('notification_log');

  Future<void> _createAndroidChannels() async {
    final android =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = [
      AndroidNotificationChannel(
        'morning_budget',
        'Ngân sách buổi sáng',
        description: 'Thông báo ngân sách mỗi buổi sáng lúc 7h',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'overspend_alerts',
        'Cảnh báo vượt chi',
        description: 'Thông báo vượt ngưỡng chi tiêu trong ngày',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'habit_streaks',
        'Nhắc chuỗi thói quen',
        description: 'Thông báo nhắc nhở và cập nhật chuỗi thói quen',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'evening_summary',
        'Tổng kết buổi tối',
        description: 'Thông báo tổng kết chi tiêu vào buổi tối',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'weekly_insight',
        'Nhận xét hàng tuần',
        description: 'Thông báo so sánh chi tiêu hàng tuần',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'debt_reminders',
        'Nhắc nợ',
        description: 'Thông báo nhắc các khoản nợ chưa thu hồi',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'end_of_month',
        'Dự báo cuối tháng',
        description: 'Thông báo dự báo tổng chi tiêu từ ngày 25 trở đi',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'savings_milestones',
        'Mốc tiết kiệm',
        description: 'Thông báo khi đạt mốc mục tiêu tiết kiệm',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'velocity_alerts',
        'Cảnh báo tốc độ chi',
        description: 'Cảnh báo khi dự báo chi tiêu vượt hạn mức sớm',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'category_alerts',
        'Cảnh báo hạng mục',
        description: 'Thông báo khi chi tiêu hạng mục chạm mốc ngân sách',
        importance: Importance.high,
      ),
    ];

    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  _ScheduledCandidate _buildMorningBudgetCandidate(AppSettings settings) {
    final formatted = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    ).format(settings.computedDailyLimit);

    return _ScheduledCandidate(
      id: _dailyMorningId,
      title: 'Chào buổi sáng! ☀️',
      body: 'Hôm nay bạn có $formatted để chi tiêu. Đi chậm và đúng mức.',
      scheduledAt: _nextDailyTime(7, 0),
      priority: _priorityMorningBudget,
      channelId: 'morning_budget',
      channelName: 'Ngân sách buổi sáng',
      channelDescription: 'Thông báo ngân sách mỗi buổi sáng lúc 7h',
    );
  }

  _ScheduledCandidate _buildEveningSummaryCandidate() {
    final now = AppTimeService.instance.now();
    final transactions = Hive.box<Transaction>('transactions').values.where(
          (transaction) =>
              transaction.date.year == now.year &&
              transaction.date.month == now.month &&
              transaction.date.day == now.day,
        );
    final count = transactions.length;
    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final formatted = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    ).format(total);

    return _ScheduledCandidate(
      id: _eveningSummaryId,
      title: 'Tổng kết buổi tối 🌙',
      body: 'Hôm nay bạn đã có $count giao dịch, tổng chi $formatted.',
      scheduledAt: _nextDailyTime(21, 0),
      priority: _priorityEveningSummary,
      channelId: 'evening_summary',
      channelName: 'Tổng kết buổi tối',
      channelDescription: 'Thông báo tổng kết chi tiêu vào buổi tối',
    );
  }

  _ScheduledCandidate _buildWeeklyInsightCandidate() {
    final now = AppTimeService.instance.now();
    final transactions = Hive.box<Transaction>('transactions').values.toList();
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));

    final thisWeekTotal = transactions
        .where((transaction) => !transaction.date.isBefore(startOfThisWeek))
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final lastWeekTotal = transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(startOfLastWeek) &&
              !transaction.date.isAfter(endOfLastWeek),
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final difference = thisWeekTotal - lastWeekTotal;
    final differenceText = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    ).format(difference.abs());
    final body = difference == 0
        ? 'Chi tiêu tuần này gần như bằng tuần trước. Nhịp chi tiêu đang ổn định.'
        : difference > 0
            ? 'Tuần này bạn chi nhiều hơn tuần trước $differenceText. Cần xem lại nhóm chi tiêu lớn.'
            : 'Tuần này bạn đã tiết kiệm hơn tuần trước $differenceText. Tiếp tục giữ nhịp này.';

    return _ScheduledCandidate(
      id: _weeklyInsightId,
      title: 'Nhận xét hàng tuần 📊',
      body: body,
      scheduledAt: _nextWeekdayTime(DateTime.sunday, 10, 0),
      priority: _priorityWeeklyInsight,
      channelId: 'weekly_insight',
      channelName: 'Nhận xét hàng tuần',
      channelDescription: 'Thông báo so sánh chi tiêu hàng tuần',
    );
  }

  List<_ScheduledCandidate> _buildHabitCandidates() {
    final habits = Hive.box<HabitBreaker>('habitBreakers')
        .values
        .where((habit) => habit.isActive)
        .toList()
      ..sort(
          (left, right) => right.currentStreak.compareTo(left.currentStreak));

    final selected = habits.take(_habitMaxCount).toList();
    return List.generate(selected.length, (index) {
      final habit = selected[index];
      final body = habit.isFrozen
          ? 'Chuỗi "${habit.habitName}" đang đóng băng. Còn ${habit.freezeDaysRemaining} ngày để hồi phục.'
          : habit.hasActiveShield
              ? '"${habit.habitName}" đang ở chuỗi nâng cấp và có lá chắn. Đừng phá nhịp hôm nay.'
              : 'Hôm nay tiếp tục giữ chuỗi "${habit.habitName}" ở mốc ${habit.currentStreak} ngày.';

      return _ScheduledCandidate(
        id: _habitBaseId + index,
        title: 'Nhớ chuỗi thói quen 💪',
        body: body,
        scheduledAt: _nextDailyTime(8, 0),
        priority: _priorityHabitStreak,
        channelId: 'habit_streaks',
        channelName: 'Nhắc chuỗi thói quen',
        channelDescription: 'Thông báo nhắc nhở và cập nhật chuỗi thói quen',
      );
    });
  }

  List<_ScheduledCandidate> _buildDebtReminderCandidates() {
    final debts = Hive.box<DebtRecord>('debtRecords')
        .values
        .where((debt) => !debt.isPaid)
        .toList()
      ..sort((left, right) => left.date.compareTo(right.date));

    final selected = debts.take(_debtMaxCount).toList();
    return List.generate(selected.length, (index) {
      final debt = selected[index];
      final amount = NumberFormat.currency(
        locale: 'vi',
        symbol: '₫',
        decimalDigits: 0,
      ).format(debt.amount);

      return _ScheduledCandidate(
        id: _debtBaseId + index,
        title: 'Nhắc nợ 💸',
        body:
            '${debt.debtorName} còn nợ bạn $amount cho "${debt.description}".',
        scheduledAt: _nextDebtReminderDate(debt.date),
        priority: _priorityDebtReminder,
        channelId: 'debt_reminders',
        channelName: 'Nhắc nợ',
        channelDescription: 'Thông báo nhắc các khoản nợ chưa thu hồi',
      );
    });
  }

  _ScheduledCandidate? _buildEndOfMonthCandidate() {
    final now = AppTimeService.instance.now();
    final firstWindow = DateTime(now.year, now.month, 25, 12);
    DateTime scheduledAt;

    if (now.day < 25) {
      scheduledAt = firstWindow;
    } else {
      scheduledAt = DateTime(now.year, now.month, now.day, 12);
      if (!scheduledAt.isAfter(now)) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }
    }

    final transactions = Hive.box<Transaction>('transactions')
        .values
        .where(
          (transaction) =>
              transaction.date.year == now.year &&
              transaction.date.month == now.month,
        )
        .toList();
    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final average = now.day > 0 ? total / now.day : 0;
    final projected = total + (average * (daysInMonth - now.day));
    final formatted = NumberFormat.currency(
      locale: 'vi',
      symbol: '₫',
      decimalDigits: 0,
    ).format(projected);

    return _ScheduledCandidate(
      id: _endOfMonthId,
      title: 'Dự báo cuối tháng ⚡',
      body: 'Nếu giữ nhịp hiện tại, tổng chi tháng này có thể đạt $formatted.',
      scheduledAt: scheduledAt,
      priority: _priorityEndOfMonth,
      channelId: 'end_of_month',
      channelName: 'Dự báo cuối tháng',
      channelDescription: 'Thông báo dự báo tổng chi tiêu từ ngày 25 trở đi',
    );
  }

  Future<void> _scheduleCandidate(_ScheduledCandidate candidate) async {
    final reserved = await _reservePlannedNotification(candidate);
    if (!reserved) return;

    try {
      final now = DateTime.now();
      final durationToWait = candidate.scheduledAt.difference(
        AppTimeService.instance.isOverrideActive
            ? AppTimeService.instance.now()
            : now,
      );
      final tzDate = tz.TZDateTime.now(tz.local).add(
        durationToWait.isNegative ? Duration.zero : durationToWait,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        candidate.id,
        candidate.title,
        candidate.body,
        tzDate,
        _notificationDetails(
          androidChannelId: candidate.channelId,
          androidChannelName: candidate.channelName,
          androidChannelDescription: candidate.channelDescription,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      await _removePlannedNotification(candidate.id);
      rethrow;
    }
  }

  Future<bool> _reservePlannedNotification(
      _ScheduledCandidate candidate) async {
    final planned = _plannedNotifications;
    final sameDay = planned
        .where(
          (entry) =>
              _dayKey(DateTime.parse(entry['scheduledAt'] as String)) ==
              _dayKey(candidate.scheduledAt),
        )
        .toList()
      ..sort(
        (left, right) =>
            (left['priority'] as int).compareTo(right['priority'] as int),
      );

    if (sameDay.length >= _maxNotificationsPerDay) {
      final weakest = sameDay.first;
      if ((weakest['priority'] as int) >= candidate.priority) {
        return false;
      }

      await flutterLocalNotificationsPlugin.cancel(weakest['id'] as int);
      planned.removeWhere((entry) => entry['id'] == weakest['id']);
    }

    planned.add({
      'id': candidate.id,
      'scheduledAt': candidate.scheduledAt.toIso8601String(),
      'priority': candidate.priority,
    });
    await _notificationLogBox.put(_plannedLogKey, planned);
    return true;
  }

  Future<bool> _canSendNotification({required int priority}) async {
    final sentToday = _sentNotifications.where(
      (entry) =>
          _dayKey(DateTime.parse(entry['sentAt'] as String)) ==
          _dayKey(AppTimeService.instance.now()),
    );
    final plannedToday = _plannedNotifications
        .where(
          (entry) =>
              _dayKey(DateTime.parse(entry['scheduledAt'] as String)) ==
              _dayKey(AppTimeService.instance.now()),
        )
        .toList()
      ..sort(
        (left, right) =>
            (left['priority'] as int).compareTo(right['priority'] as int),
      );

    if (sentToday.length + plannedToday.length < _maxNotificationsPerDay) {
      return true;
    }

    for (final entry in plannedToday) {
      if ((entry['priority'] as int) < priority) {
        await flutterLocalNotificationsPlugin.cancel(entry['id'] as int);
        await _removePlannedNotification(entry['id'] as int);
        return true;
      }
    }

    return false;
  }

  Future<void> _logNotificationSent({
    required int id,
    required int priority,
  }) async {
    final sent = _sentNotifications;
    sent.add({
      'id': id,
      'sentAt': AppTimeService.instance.now().toIso8601String(),
      'priority': priority,
    });
    await _notificationLogBox.put(_sentLogKey, sent);
    await _removePlannedNotification(id);
  }

  Future<void> _cancelSmartScheduledNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(_dailyMorningId);
    await flutterLocalNotificationsPlugin.cancel(_eveningSummaryId);
    await flutterLocalNotificationsPlugin.cancel(_weeklyInsightId);
    await flutterLocalNotificationsPlugin.cancel(_endOfMonthId);
    for (var id = _habitBaseId; id < _habitBaseId + _habitMaxCount; id++) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }
    for (var id = _debtBaseId; id < _debtBaseId + _debtMaxCount; id++) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }
  }

  Future<void> _clearSmartPlannedNotifications() async {
    final planned = _plannedNotifications
        .where((entry) => !_isSmartScheduledId(entry['id'] as int))
        .toList();
    await _notificationLogBox.put(_plannedLogKey, planned);
  }

  Future<void> _removePlannedNotification(int id) async {
    final planned =
        _plannedNotifications.where((entry) => entry['id'] != id).toList();
    await _notificationLogBox.put(_plannedLogKey, planned);
  }

  bool _isSmartScheduledId(int id) {
    if (id == _dailyMorningId ||
        id == _eveningSummaryId ||
        id == _weeklyInsightId ||
        id == _endOfMonthId) {
      return true;
    }
    if (id >= _habitBaseId && id < _habitBaseId + _habitMaxCount) {
      return true;
    }
    if (id >= _debtBaseId && id < _debtBaseId + _debtMaxCount) {
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> get _sentNotifications {
    final raw = _notificationLogBox.get(_sentLogKey, defaultValue: <dynamic>[]);
    return _sanitizeLogEntries(raw, 'sentAt');
  }

  List<Map<String, dynamic>> get _plannedNotifications {
    final raw = _notificationLogBox.get(
      _plannedLogKey,
      defaultValue: <dynamic>[],
    );
    return _sanitizeLogEntries(raw, 'scheduledAt');
  }

  List<String> get _overspendHistory {
    final raw = _notificationLogBox.get(
      _overspendHistoryKey,
      defaultValue: <dynamic>[],
    );
    return List<String>.from(raw);
  }

  List<String> get _velocityHistory {
    final raw = _notificationLogBox.get(
      _velocityHistoryKey,
      defaultValue: <dynamic>[],
    );
    return List<String>.from(raw);
  }

  List<String> get _categoryThresholdHistory {
    final raw = _notificationLogBox.get(
      _categoryThresholdHistoryKey,
      defaultValue: <dynamic>[],
    );
    return List<String>.from(raw);
  }

  List<Map<String, dynamic>> _sanitizeLogEntries(dynamic raw, String timeKey) {
    final now = AppTimeService.instance.now();
    final entries = List<Map<String, dynamic>>.from(
      (raw as List).whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
    );
    entries.removeWhere((entry) {
      final timestamp = entry[timeKey];
      if (timestamp is! String) return true;
      final parsed = DateTime.tryParse(timestamp);
      if (parsed == null) return true;
      return parsed.isBefore(DateTime(now.year, now.month, now.day));
    });
    return entries;
  }

  NotificationDetails _notificationDetails({
    required String androidChannelId,
    required String androidChannelName,
    required String androidChannelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
  }

  DateTime _nextDailyTime(int hour, int minute) {
    final now = AppTimeService.instance.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  DateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = AppTimeService.instance.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  DateTime _nextDebtReminderDate(DateTime startDate) {
    final now = AppTimeService.instance.now();
    var scheduled = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      11,
      0,
    ).add(const Duration(days: 3));
    while (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 3));
    }
    return scheduled;
  }

  String _dayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _nextInstanceLocal(int day, int? month, bool isYearly) {
    final now = DateTime.now();

    if (isYearly && month != null) {
      var scheduledDate = DateTime(now.year, month, day, 9, 0, 0);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = DateTime(now.year + 1, month, day, 9, 0, 0);
      }
      return scheduledDate;
    }

    var scheduledDate = DateTime(now.year, now.month, day, 9, 0, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      if (scheduledDate.day != day || scheduledDate.month == now.month) {
        var nextMonth = now.month + 1;
        var nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear = now.year + 1;
        }
        scheduledDate = DateTime(nextYear, nextMonth, day, 9, 0, 0);
      }
    }
    return scheduledDate;
  }
}

class _ScheduledCandidate {
  const _ScheduledCandidate({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.priority,
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final int priority;
  final String channelId;
  final String channelName;
  final String channelDescription;
}
