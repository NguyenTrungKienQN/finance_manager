import 'package:hive/hive.dart';

part 'savings_goal_model.g.dart';

@HiveType(typeId: 2)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double targetAmount;

  @HiveField(3)
  double savedAmount;

  @HiveField(4)
  DateTime? deadline;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isCompleted;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    DateTime? createdAt,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  double get remaining => (targetAmount - savedAmount).clamp(0, targetAmount);
}
