import 'package:hive/hive.dart';
import '../models/income_record_model.dart';
import '../models/settings_model.dart';

class IncomeService {
  IncomeService._();
  static final IncomeService instance = IncomeService._();

  Box<IncomeRecord> get _box => Hive.box<IncomeRecord>('incomes');

  Future<void> initialize() async {
    if (_box.isEmpty) {
      await _migrateFromSettings();
    }
  }

  Future<void> _migrateFromSettings() async {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings');
    if (settings != null) {
      final now = DateTime.now();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final record = IncomeRecord(
        id: id,
        month: now.month,
        year: now.year,
        name: 'Lương chính',
        amount: settings.monthlySalary,
        isRecurring: true,
      );
      await _box.add(record);
    }
  }

  List<IncomeRecord> getIncomesForMonth(int year, int month) {
    // 1. Try to find records for the exact month/year
    final records = _box.values
        .where((r) => r.year == year && r.month == month)
        .toList();

    if (records.isNotEmpty) {
      return records;
    }

    // 2. If no records for this month, copy recurring records from the most recent past month
    final pastRecords = _box.values
        .where((r) {
          if (r.year < year) return true;
          if (r.year == year && r.month < month) return true;
          return false;
        })
        .toList();

    if (pastRecords.isEmpty) return [];

    // Find the latest year/month that has ANY records
    pastRecords.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });

    final latestYear = pastRecords.first.year;
    final latestMonth = pastRecords.first.month;

    final recurringToCopy = pastRecords
        .where((r) => r.year == latestYear && r.month == latestMonth && r.isRecurring)
        .toList();

    if (recurringToCopy.isEmpty) return [];

    // Create copies for the requested month
    final newRecords = recurringToCopy.map((r) {
      return IncomeRecord(
        id: '${r.id}_$year$month',
        month: month,
        year: year,
        name: r.name,
        amount: r.amount,
        isRecurring: true,
      );
    }).toList();

    // Persist the copies so they can be edited independently
    for (var r in newRecords) {
      _box.add(r);
    }

    return newRecords;
  }

  double getTotalIncome(DateTime date) {
    final records = getIncomesForMonth(date.year, date.month);
    return records.fold(0.0, (sum, r) => sum + r.amount);
  }

  double getTotalIncomeInRange(DateTime start, DateTime end) {
    double total = 0;
    // Iterate through each month in the range
    DateTime current = DateTime(start.year, start.month, 1);
    while (current.isBefore(end) || (current.year == end.year && current.month == end.month)) {
      total += getTotalIncome(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return total;
  }

  Future<void> addIncome(IncomeRecord record) async {
    await _box.add(record);
  }

  Future<void> deleteIncome(IncomeRecord record) async {
    await record.delete();
  }

  Future<void> updateIncome(IncomeRecord record) async {
    await record.save();
  }
}
