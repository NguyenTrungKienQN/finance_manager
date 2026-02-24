import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0)
  double dailyLimit;

  @HiveField(1)
  bool isFirstInstall;

  @HiveField(2)
  String userName; // e.g., "Mẹ", "Bố", or custom name

  @HiveField(3)
  double monthlySalary;

  @HiveField(4)
  String themeMode; // "system", "light", "dark"

  @HiveField(5)
  int freeAiUses; // 5 free uses with default key

  @HiveField(6)
  String? geminiApiKey; // User's own key for unlimited

  AppSettings({
    this.dailyLimit = 500000,
    this.isFirstInstall = true,
    this.userName = "Bạn",
    this.monthlySalary = 15000000,
    this.themeMode = "system",
    this.freeAiUses = 5,
    this.geminiApiKey,
  });

  /// Auto-calculate daily limit from salary
  double get computedDailyLimit {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return monthlySalary / daysInMonth;
  }
}
