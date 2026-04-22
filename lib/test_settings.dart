import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finance_manager/models/settings_model.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(AppSettingsAdapter());
  
  final box = await Hive.openBox<AppSettings>('settings');
  final settings = box.get('appSettings') ?? AppSettings();
  
  debugPrint('========================');
  debugPrint('HIVE DUMP:');
  debugPrint('Monthly Salary: ${settings.monthlySalary}');
  debugPrint('Initial Month Spent: ${settings.initialMonthSpent}');
  debugPrint('Tracking Start Date: ${settings.trackingStartDate}');
  debugPrint('Daily Limit: ${settings.dailyLimit}');
  debugPrint('========================');
}
