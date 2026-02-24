import 'package:hive/hive.dart';

part 'habit_breaker_model.g.dart';

@HiveType(typeId: 6)
class HabitBreaker extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String habitName; // e.g. "Trà sữa"

  @HiveField(2)
  String iconName; // Material icon name string

  @HiveField(3)
  DateTime startDate; // When current streak started

  @HiveField(4)
  int currentStreak; // Consecutive days

  @HiveField(5)
  int bestStreak; // Personal record

  @HiveField(6)
  DateTime lastCheckDate; // Last date streak was verified/advanced

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  List<String> badges; // Earned badge IDs

  HabitBreaker({
    required this.id,
    required this.habitName,
    this.iconName = 'local_cafe',
    DateTime? startDate,
    this.currentStreak = 0,
    this.bestStreak = 0,
    DateTime? lastCheckDate,
    this.isActive = true,
    List<String>? badges,
  }) : startDate = startDate ?? DateTime.now(),
       lastCheckDate = lastCheckDate ?? DateTime.now(),
       badges = badges ?? [];

  /// Advance streak if a new calendar day has passed
  bool advanceStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastCheck = DateTime(
      lastCheckDate.year,
      lastCheckDate.month,
      lastCheckDate.day,
    );

    if (today.isAfter(lastCheck)) {
      final daysDiff = today.difference(lastCheck).inDays;
      currentStreak += daysDiff;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
      lastCheckDate = now;
      _checkBadges();
      save();
      return true;
    }
    return false;
  }

  /// Reset streak (relapse)
  void resetStreak() {
    if (currentStreak > bestStreak) bestStreak = currentStreak;
    currentStreak = 0;
    startDate = DateTime.now();
    lastCheckDate = DateTime.now();
    save();
  }

  void _checkBadges() {
    if (currentStreak >= 3 && !badges.contains('starter')) {
      badges.add('starter');
    }
    if (currentStreak >= 7 && !badges.contains('warrior')) {
      badges.add('warrior');
    }
    if (currentStreak >= 14 && !badges.contains('persistent')) {
      badges.add('persistent');
    }
    if (currentStreak >= 30 && !badges.contains('legend')) {
      badges.add('legend');
    }
  }
}
