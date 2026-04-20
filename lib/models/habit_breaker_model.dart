import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../services/app_time_service.dart';

part 'habit_breaker_model.g.dart';

enum RelapseResult { shieldAbsorbed, frozen, fullReset }

@HiveType(typeId: 6)
class HabitBreaker extends HiveObject {
  static const String tierRegular = 'regular';
  static const String tierPurple = 'purple';
  static const int freezeRecoveryDays = 3;
  static const int purpleUpgradeDays = 7;
  static const int dayStateRetentionDays = 30;

  @HiveField(0)
  final String id;

  @HiveField(1)
  String habitName;

  @HiveField(2)
  String iconName;

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  int currentStreak;

  @HiveField(5)
  int bestStreak;

  @HiveField(6)
  DateTime lastCheckDate;

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  List<String> badges;

  @HiveField(9, defaultValue: tierRegular)
  String streakTier;

  @HiveField(10, defaultValue: false)
  bool hasShield;

  @HiveField(11, defaultValue: false)
  bool isFrozen;

  @HiveField(12)
  DateTime? frozenDate;

  @HiveField(13, defaultValue: false)
  bool wasPurpleBeforeFreeze;

  @HiveField(14, defaultValue: 0)
  int cleanDaysSinceRecovery;

  @HiveField(15, defaultValue: <String, String>{})
  Map<String, String> dayStates;

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
    this.streakTier = tierRegular,
    this.hasShield = false,
    this.isFrozen = false,
    this.frozenDate,
    this.wasPurpleBeforeFreeze = false,
    this.cleanDaysSinceRecovery = 0,
    Map<String, String>? dayStates,
  })  : startDate = startDate ?? AppTimeService.instance.now(),
        lastCheckDate = lastCheckDate ?? AppTimeService.instance.now(),
        badges = badges ?? [],
        dayStates = Map<String, String>.from(dayStates ?? const {}) {
    _applyBackwardCompatibility();
  }

  bool get isPurpleTier => streakTier == tierPurple;
  bool get hasActiveShield => isPurpleTier && hasShield;
  bool get isPurpleWithoutShield => isPurpleTier && !hasShield;
  bool get showsPurpleFrozenState => isFrozen && wasPurpleBeforeFreeze;
  bool get needsPurpleRecovery =>
      !isFrozen && !isPurpleTier && wasPurpleBeforeFreeze;

  int get freezeDaysRemaining {
    if (!isFrozen || frozenDate == null) return 0;
    final diff = _dateOnly(AppTimeService.instance.now())
        .difference(_dateOnly(frozenDate!))
        .inDays;
    return (freezeRecoveryDays - diff).clamp(0, freezeRecoveryDays);
  }

  String getStatusText() {
    if (isFrozen) {
      if (showsPurpleFrozenState) {
        return '🧊 Đóng băng (nâng cấp) · Còn $freezeDaysRemaining ngày';
      }
      return '🧊 Đóng băng · Còn $freezeDaysRemaining ngày để hồi phục';
    }

    if (hasActiveShield) {
      return '✨ Chuỗi nâng cấp · Lá chắn hoạt động 🛡️';
    }

    if (isPurpleWithoutShield) {
      return '✨ Chuỗi nâng cấp · Không có lá chắn ⚠️';
    }

    if (needsPurpleRecovery) {
      final remaining = (purpleUpgradeDays - cleanDaysSinceRecovery).clamp(
        0,
        purpleUpgradeDays,
      );
      return 'Chuỗi thường · Thêm $remaining ngày để nâng cấp';
    }

    final remaining = (purpleUpgradeDays - currentStreak).clamp(
      0,
      purpleUpgradeDays,
    );
    return 'Chuỗi thường · Thêm $remaining ngày để nâng cấp';
  }

  String getWidgetState() {
    if (isFrozen) return 'frozen';
    if (currentStreak == 0 && bestStreak > 0) return 'failed';
    return 'active';
  }

  bool ensureBackwardCompatibility({bool persist = true}) {
    final changed = _applyBackwardCompatibility();
    if (changed && persist && isInBox) {
      save();
    }
    return changed;
  }

  bool advanceStreak() {
    final now = AppTimeService.instance.now();
    final today = _dateOnly(now);
    var changed = _applyBackwardCompatibility(referenceDate: today);
    final lastCheck = _dateOnly(lastCheckDate);

    if (!today.isAfter(lastCheck)) {
      if (changed) {
        save();
      }
      return changed;
    }

    for (var cursor = lastCheck.add(const Duration(days: 1));
        !cursor.isAfter(today);
        cursor = cursor.add(const Duration(days: 1))) {
      if (isFrozen) {
        _recordDayState(cursor, 'frozen');

        if (frozenDate != null &&
            _dateOnly(cursor).difference(_dateOnly(frozenDate!)).inDays >=
                freezeRecoveryDays) {
          isFrozen = false;
          streakTier = tierRegular;
          hasShield = false;
          cleanDaysSinceRecovery = 0;
        }
      } else {
        currentStreak += 1;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
        if (needsPurpleRecovery) {
          cleanDaysSinceRecovery += 1;
        }

        _recordDayState(cursor, 'clean');
        _maybeUpgrade(cursor);
        _checkBadges();
      }

      lastCheckDate = cursor;
      changed = true;
    }

    if (changed) {
      _pruneDayStates(today);
      save();
    }

    return changed;
  }

  RelapseResult handleRelapse() {
    final now = AppTimeService.instance.now();
    final today = _dateOnly(now);
    _applyBackwardCompatibility(referenceDate: today);

    if (isFrozen) {
      _recordDayState(today, 'reset');
      _fullReset(now);
      save();
      return RelapseResult.fullReset;
    }

    if (hasActiveShield) {
      hasShield = false;
      lastCheckDate = now;
      _recordDayState(today, 'shield_used');
      _pruneDayStates(today);
      save();
      return RelapseResult.shieldAbsorbed;
    }

    isFrozen = true;
    frozenDate = now;
    wasPurpleBeforeFreeze = isPurpleTier;
    streakTier = tierRegular;
    hasShield = false;
    cleanDaysSinceRecovery = 0;
    lastCheckDate = now;
    _recordDayState(today, 'frozen');
    _pruneDayStates(today);
    save();
    return RelapseResult.frozen;
  }

  void resetStreak() {
    _fullReset(AppTimeService.instance.now());
    save();
  }

  String? dayStateFor(DateTime day) {
    return dayStates[_keyForDay(day)];
  }

  void _fullReset(DateTime at) {
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    currentStreak = 0;
    streakTier = tierRegular;
    hasShield = false;
    isFrozen = false;
    frozenDate = null;
    wasPurpleBeforeFreeze = false;
    cleanDaysSinceRecovery = 0;
    startDate = at;
    lastCheckDate = at;
    _checkBadges();
  }

  void _maybeUpgrade(DateTime date) {
    if (isPurpleTier) return;

    if (needsPurpleRecovery) {
      if (cleanDaysSinceRecovery >= purpleUpgradeDays) {
        streakTier = tierPurple;
        hasShield = true;
        wasPurpleBeforeFreeze = false;
        cleanDaysSinceRecovery = 0;
        _recordDayState(date, 'upgrade');
      }
      return;
    }

    if (currentStreak >= purpleUpgradeDays) {
      streakTier = tierPurple;
      hasShield = true;
      _recordDayState(date, 'upgrade');
    }
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

  void _recordDayState(DateTime day, String state) {
    dayStates[_keyForDay(day)] = state;
  }

  void _pruneDayStates(DateTime today) {
    final cutoff = today.subtract(const Duration(days: dayStateRetentionDays));
    dayStates.removeWhere((key, value) {
      final parsed = DateTime.tryParse(key);
      return parsed == null || parsed.isBefore(cutoff);
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _keyForDay(DateTime day) =>
      DateFormat('yyyy-MM-dd').format(_dateOnly(day));

  bool _applyBackwardCompatibility({DateTime? referenceDate}) {
    var changed = false;
    final today = _dateOnly(referenceDate ?? AppTimeService.instance.now());

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
      changed = true;
    }

    final badgeCount = badges.length;
    _checkBadges();
    if (badges.length != badgeCount) {
      changed = true;
    }

    if (isFrozen) {
      if (frozenDate == null) {
        frozenDate = lastCheckDate;
        changed = true;
      }

      if (streakTier != tierRegular) {
        streakTier = tierRegular;
        changed = true;
      }

      if (hasShield) {
        hasShield = false;
        changed = true;
      }
    } else if (!wasPurpleBeforeFreeze &&
        streakTier == tierRegular &&
        currentStreak >= purpleUpgradeDays) {
      streakTier = tierPurple;
      hasShield = true;
      changed = true;
    }

    if (dayStates.isEmpty && currentStreak > 0 && !isFrozen) {
      final backfillDays = currentStreak > dayStateRetentionDays
          ? dayStateRetentionDays
          : currentStreak;
      final anchorDay = _dateOnly(lastCheckDate);
      for (var offset = 0; offset < backfillDays; offset++) {
        final day = anchorDay.subtract(Duration(days: offset));
        dayStates[_keyForDay(day)] = 'clean';
      }
      changed = true;
    }

    final beforePruneCount = dayStates.length;
    _pruneDayStates(today);
    if (dayStates.length != beforePruneCount) {
      changed = true;
    }

    return changed;
  }
}
