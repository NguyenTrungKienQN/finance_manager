import 'package:hive/hive.dart';

part 'debt_record_model.g.dart';

@HiveType(typeId: 5)
class DebtRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String debtorName; // Name of person who owes money

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  bool isPaid;

  DebtRecord({
    required this.id,
    required this.debtorName,
    required this.amount,
    required this.description,
    required this.date,
    this.isPaid = false,
  });
}
