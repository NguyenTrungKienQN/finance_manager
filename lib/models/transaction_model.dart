import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount; // Tổng tiền = unitPrice * quantity

  @HiveField(2)
  final String category;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final bool isOverBudget;

  @HiveField(5)
  final String? notes;

  @HiveField(6)
  final double? unitPrice; // Giá mỗi đơn vị

  @HiveField(7)
  final int? quantity; // Số lượng (default: 1)

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.isOverBudget = false,
    this.notes,
    this.unitPrice,
    this.quantity,
  });
}
