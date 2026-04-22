import 'package:hive/hive.dart';
import '../services/app_time_service.dart';
import 'package:finance_manager/models/transaction_model.dart';
import 'package:finance_manager/models/spending_category_model.dart';
import 'package:finance_manager/services/category_registry.dart';
import 'package:finance_manager/services/income_service.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0, defaultValue: 500000.0)
  double dailyLimit;

  @HiveField(1, defaultValue: true)
  bool isFirstInstall;

  @HiveField(2, defaultValue: "Bạn")
  String userName; // e.g., "Mẹ", "Bố", or custom name

  @HiveField(3, defaultValue: 15000000.0)
  double monthlySalary;

  @HiveField(4, defaultValue: "system")
  String themeMode; // "system", "light", "dark"

  @HiveField(5, defaultValue: 5)
  int freeAiUses; // 5 free uses with default key

  @HiveField(6)
  String? geminiApiKey; // User's own key for unlimited

  @HiveField(7, defaultValue: false)
  bool hasSeenOtterIntro; // Otter welcome card dismissed

  @HiveField(8, defaultValue: true)
  bool notifMorningBudget;

  @HiveField(9, defaultValue: true)
  bool notifOverspendAlert;

  @HiveField(10, defaultValue: true)
  bool notifHabitStreak;

  @HiveField(11, defaultValue: false)
  bool notifEveningSummary;

  @HiveField(12, defaultValue: false)
  bool notifWeeklyInsight;

  @HiveField(13, defaultValue: false)
  bool notifDebtReminder;

  @HiveField(14, defaultValue: false)
  bool notifEndOfMonth;

  @HiveField(15, defaultValue: false)
  bool notifSavingsMilestone;

  @HiveField(16, defaultValue: false)
  bool enableAppLock;

  @HiveField(17, defaultValue: 0.0)
  double safeBalance;

  @HiveField(18)
  DateTime? trackingStartDate;

  @HiveField(19, defaultValue: 0.0)
  double initialMonthSpent;

  AppSettings({
    this.dailyLimit = 500000,
    this.isFirstInstall = true,
    this.userName = "Bạn",
    this.monthlySalary = 15000000,
    this.themeMode = "system",
    this.freeAiUses = 5,
    this.geminiApiKey,
    this.hasSeenOtterIntro = false,
    this.notifMorningBudget = true,
    this.notifOverspendAlert = true,
    this.notifHabitStreak = true,
    this.notifEveningSummary = false,
    this.notifWeeklyInsight = false,
    this.notifDebtReminder = false,
    this.notifEndOfMonth = false,
    this.notifSavingsMilestone = false,
    this.enableAppLock = false,
    this.safeBalance = 0.0,
    this.trackingStartDate,
    this.initialMonthSpent = 0.0,
    this.headerBackgroundImagePath,
  });

  @HiveField(20)
  String? headerBackgroundImagePath;

  bool isTrackingMonth(DateTime date) {
    final start = trackingStartDate;
    return start != null &&
        start.year == date.year &&
        start.month == date.month;
  }

  bool tracksDate(DateTime date) {
    if (trackingStartDate == null) return false;
    final startMonth = DateTime(
      trackingStartDate!.year,
      trackingStartDate!.month,
      1,
    );
    final end = DateTime(date.year, date.month, date.day);
    return !end.isBefore(startMonth);
  }

  int trackingStartDayFor(DateTime date) {
    return isTrackingMonth(date) ? trackingStartDate!.day : 1;
  }

  double baseDailyLimitFor(DateTime date) {
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    if (daysInMonth <= 0) return 0;

    final totalIncome = totalIncomeForDate(date);
    final monthlyFixed = CategoryRegistry.instance.totalMonthlyFixed();
    
    if (!isTrackingMonth(date)) {
      final availableSalary = totalIncome - monthlyFixed;
      return (availableSalary / daysInMonth).roundToDouble();
    }

    final remainingDays = daysInMonth - trackingStartDate!.day + 1;
    if (remainingDays <= 0) return 0;

    final remainingBudgetAtSetup = totalIncome - monthlyFixed;
    
    final normalizedRemainingBudget = remainingBudgetAtSetup < 0
        ? 0.0
        : remainingBudgetAtSetup;

    return (normalizedRemainingBudget / remainingDays).roundToDouble();
  }

  double totalIncomeForDate(DateTime date) {
    return IncomeService.instance.getTotalIncome(date);
  }

  double calculateDailyLimitForDate(
    DateTime date,
    Iterable<Transaction> transactions,
  ) {
    if (!tracksDate(date)) {
      return baseDailyLimitFor(date); // Fallback to base limit instead of locking to 0
    }

    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final baseDailyLimit = baseDailyLimitFor(date);
    final startDay = trackingStartDayFor(date);

    double monthSpentBeforeDate = 0;
    for (final transaction in transactions) {
      if (transaction.date.year != date.year ||
          transaction.date.month != date.month) {
        continue;
      }
      
      // Only count non-safe, NON-MONTHLY transactions that happened BEFORE the selected date.
      if (transaction.date.day < date.day) {
        final nonSafeAmount = transaction.amount - transaction.safeAmount;
        final cat = CategoryRegistry.instance.getByName(transaction.category);
        if (cat?.budgetPeriod != BudgetPeriod.monthly) {
          monthSpentBeforeDate += nonSafeAmount;
        }
      }
    }

    final daysPassedBeforeDate = (date.day - startDay).clamp(0, daysInMonth);
    final accruedBudget = daysPassedBeforeDate * baseDailyLimit;
    final dynamicDailyLimit =
        baseDailyLimit + accruedBudget - monthSpentBeforeDate;

    return dynamicDailyLimit < 0 ? 0 : dynamicDailyLimit.roundToDouble();
  }

  /// Auto-calculate today's daily limit dynamically with rollover.
  double get computedDailyLimit {
    final now = AppTimeService.instance.now();

    if (!Hive.isBoxOpen('transactions')) {
      return baseDailyLimitFor(now).clamp(0, double.infinity).toDouble();
    }

    final txBox = Hive.box<Transaction>('transactions');
    return calculateDailyLimitForDate(now, txBox.values);
  }
}
