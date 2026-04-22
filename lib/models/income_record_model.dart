import 'package:hive/hive.dart';

part 'income_record_model.g.dart';

@HiveType(typeId: 9)
class IncomeRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int month;

  @HiveField(2)
  final int year;

  @HiveField(3)
  String name;

  @HiveField(4)
  double amount;

  @HiveField(5)
  bool isRecurring;

  @HiveField(6)
  DateTime createdAt;

  IncomeRecord({
    required this.id,
    required this.month,
    required this.year,
    required this.name,
    required this.amount,
    this.isRecurring = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
