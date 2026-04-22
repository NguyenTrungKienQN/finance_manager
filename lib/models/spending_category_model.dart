import 'package:hive/hive.dart';

part 'spending_category_model.g.dart';

@HiveType(typeId: 8)
enum BudgetPeriod {
  @HiveField(0)
  daily,
  @HiveField(1)
  monthly,
}

@HiveType(typeId: 7)
class SpendingCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String iconName; // Material icon key

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  double? budget; // null = no per-category limit

  @HiveField(5)
  BudgetPeriod? budgetPeriod;

  @HiveField(6)
  int sortOrder;

  @HiveField(7)
  bool isDefault;

  SpendingCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    this.budget,
    this.budgetPeriod,
    required this.sortOrder,
    this.isDefault = false,
  });
}
