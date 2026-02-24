import 'package:hive/hive.dart';

part 'recurring_transaction_model.g.dart';

@HiveType(typeId: 4)
enum RecurringFrequency {
  @HiveField(0)
  monthly,
  @HiveField(1)
  yearly,
}

@HiveType(typeId: 3)
class RecurringTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final int dayOfMonth; // 1-31

  @HiveField(4)
  final bool isExpense;

  @HiveField(5)
  DateTime? lastPaidDate; // Date when last payment was made

  @HiveField(6)
  bool isActive;

  @HiveField(7, defaultValue: RecurringFrequency.monthly)
  final RecurringFrequency frequency; // monthly or yearly

  @HiveField(8)
  final int? monthOfYear; // 1-12, required if frequency == yearly

  @HiveField(9, defaultValue: 1)
  final int interval; // Default 1 (every month/year). >1 means skip (every 2 months, etc)

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.dayOfMonth,
    this.isExpense = true,
    this.lastPaidDate,
    this.isActive = true,
    this.frequency = RecurringFrequency.monthly,
    this.monthOfYear,
    this.interval = 1,
  });
}
