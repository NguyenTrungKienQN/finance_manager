import 'package:hive/hive.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';
import '../models/habit_breaker_model.dart';
import 'app_time_service.dart';

class MigrationService {
  /// Entry point for all data migrations. Should be called in main.dart after box initialization.
  static Future<void> runAllMigrations() async {
    await _migrateAppSettings();
    await _normalizeTransactions();
    await _migrateHabitBreakers();
  }

  /// Ensures AppSettings has all required fields initialized.
  static Future<void> _migrateAppSettings() async {
    final box = Hive.box<AppSettings>('settings');
    final settings = box.get('appSettings');

    if (settings != null) {
      bool changed = false;

      // Ensure safeBalance is initialized (defaults to 0.0)
      // Note: safeBalance is non-nullable double. Hive defaultValue handles it,
      // but explicit check prevents any edge-case null issues in legacy data.
      if (settings.safeBalance < 0) {
        // Should not happen but good for sanity
        settings.safeBalance = 0.0;
        changed = true;
      }

      // Check for other legacy fields that might need defaults
      if (settings.userName.isEmpty) {
        settings.userName = "Bạn";
        changed = true;
      }

      final now = AppTimeService.instance.now();
      final monthStart = DateTime(now.year, now.month, 1);
      if (settings.trackingStartDate == null) {
        settings.trackingStartDate = monthStart;
        changed = true;
      }

      if (settings.initialMonthSpent < 0) {
        settings.initialMonthSpent = 0.0;
        changed = true;
      }

      if (changed) {
        await settings.save();
      }
    }
  }

  /// Ensures existing transactions don't have nulls for critical new fields.
  static Future<void> _normalizeTransactions() async {
    final txBox = Hive.box<Transaction>('transactions');

    for (var i = 0; i < txBox.length; i++) {
      final tx = txBox.getAt(i);
      if (tx == null) continue;

      // Note: safeAmount is now non-nullable double with defaultValue 0.0 in adapter.
      // We don't need to manually check for null as the adapter replaces null with 0.0.
      // However, if we need to perform logic based on OLD state, we'd do it here.
    }
  }

  /// Leverages existing backward compatibility logic in HabitBreaker models.
  static Future<void> _migrateHabitBreakers() async {
    final habitBox = Hive.box<HabitBreaker>('habitBreakers');
    for (var habit in habitBox.values) {
      habit.ensureBackwardCompatibility();
    }
  }
}
