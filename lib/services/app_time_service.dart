import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTimeService {
  AppTimeService._();

  static final AppTimeService instance = AppTimeService._();
  static const String _overrideKey = 'debug_time_override';

  final ValueNotifier<DateTime?> overrideNotifier = ValueNotifier<DateTime?>(
    null,
  );

  DateTime now() => overrideNotifier.value ?? DateTime.now();

  bool get isOverrideActive => overrideNotifier.value != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_overrideKey);
    overrideNotifier.value = stored == null ? null : DateTime.tryParse(stored);
  }

  Future<void> setOverride(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_overrideKey);
      overrideNotifier.value = null;
      return;
    }

    final normalized = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    await prefs.setString(_overrideKey, normalized.toIso8601String());
    overrideNotifier.value = normalized;
  }

  Future<void> shiftDays(int days) async {
    await setOverride(now().add(Duration(days: days)));
  }

  Future<void> shiftHours(int hours) async {
    await setOverride(now().add(Duration(hours: hours)));
  }

  Future<void> shiftMinutes(int minutes) async {
    await setOverride(now().add(Duration(minutes: minutes)));
  }
}
