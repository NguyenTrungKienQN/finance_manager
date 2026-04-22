import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/spending_category_model.dart';

class CategoryRegistry {
  static final CategoryRegistry instance = CategoryRegistry._internal();

  CategoryRegistry._internal();

  late Box<SpendingCategory> _box;

  Future<void> initialize() async {
    _box = Hive.box<SpendingCategory>('categories');

    if (_box.isEmpty) {
      await _seedDefaults();
    }
  }

  Future<void> _seedDefaults() async {
    final defaults = [
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Ăn uống',
        iconName: 'restaurant',
        colorValue: Colors.orange.toARGB32(),
        sortOrder: 0,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Mua sắm',
        iconName: 'shopping_bag',
        colorValue: Colors.teal.toARGB32(),
        sortOrder: 1,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Giao thông',
        iconName: 'directions_car',
        colorValue: Colors.blue.toARGB32(),
        sortOrder: 2,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Giáo dục',
        iconName: 'school',
        colorValue: Colors.purple.toARGB32(),
        sortOrder: 3,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Giải trí',
        iconName: 'movie',
        colorValue: Colors.pink.toARGB32(),
        sortOrder: 4,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Y tế',
        iconName: 'medical_services',
        colorValue: Colors.red.toARGB32(),
        sortOrder: 5,
        isDefault: true,
      ),
      SpendingCategory(
        id: const Uuid().v4(),
        name: 'Khác',
        iconName: 'receipt',
        colorValue: Colors.grey.toARGB32(),
        sortOrder: 6,
        isDefault: true,
      ),
    ];

    for (var cat in defaults) {
      await _box.put(cat.id, cat);
    }
  }

  List<SpendingCategory> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  SpendingCategory? getByName(String name) {
    try {
      return _box.values.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  IconData getIcon(String categoryName) {
    final cat = getByName(categoryName);
    final iconKey = cat?.iconName ?? _predictIconKey(categoryName);
    return _iconMap[iconKey] ?? Icons.label_important_outline_rounded;
  }

  Color getColor(String categoryName) {
    final cat = getByName(categoryName);
    return cat != null ? Color(cat.colorValue) : Colors.grey;
  }

  double? getBudget(String categoryName) {
    return getByName(categoryName)?.budget;
  }

  BudgetPeriod? getBudgetPeriod(String categoryName) {
    return getByName(categoryName)?.budgetPeriod;
  }

  List<String> categoryNames() {
    return getAll().map((c) => c.name).toList();
  }

  double totalMonthlyFixed() {
    return getAll()
        .where((c) => c.budgetPeriod == BudgetPeriod.monthly && c.budget != null)
        .fold(0.0, (sum, c) => sum + (c.budget ?? 0));
  }

  double totalDailyAllocated() {
    return getAll()
        .where((c) => c.budgetPeriod == BudgetPeriod.daily && c.budget != null)
        .fold(0.0, (sum, c) => sum + (c.budget ?? 0));
  }

  double getFlexibleBudget(double baseDailyLimit) {
    final allocated = totalDailyAllocated();
    final flexible = baseDailyLimit - allocated;
    return flexible < 0 ? 0 : flexible;
  }

  Future<void> addCustomCategory(String name) async {
    if (getByName(name) != null) return;

    final iconKey = _predictIconKey(name);
    final color = _predictColor(name);

    final newCat = SpendingCategory(
      id: const Uuid().v4(),
      name: name,
      iconName: iconKey,
      colorValue: color.toARGB32(),
      sortOrder: getAll().length,
      isDefault: false,
    );

    await _box.put(newCat.id, newCat);
  }

  Future<void> deleteCategory(String id) async {
    final cat = _box.get(id);
    if (cat != null && !cat.isDefault) {
      await cat.delete();
    }
  }

  Future<void> updateCategory(SpendingCategory category) async {
    await category.save();
  }

  String _predictIconKey(String name) {
    final lowerName = name.toLowerCase();
    for (var entry in _keywordToIcon.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'label';
  }

  Color _predictColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.cyan,
      Colors.indigo,
      Colors.amber,
      Colors.deepOrange,
    ];
    return colors[name.length % colors.length];
  }

  static const Map<String, IconData> _iconMap = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'directions_car': Icons.directions_car_rounded,
    'school': Icons.school_rounded,
    'movie': Icons.movie_rounded,
    'medical_services': Icons.medical_services_rounded,
    'receipt': Icons.receipt_long_rounded,
    'home': Icons.home_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'coffee': Icons.coffee_rounded,
    'payments': Icons.payments_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'pets': Icons.pets_rounded,
    'flight': Icons.flight_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'celebration': Icons.celebration_rounded,
    'checkroom': Icons.checkroom_rounded,
    'construction': Icons.construction_rounded,
    'child_care': Icons.child_care_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'label': Icons.label_important_outline_rounded,
  };

  static const Map<String, String> _keywordToIcon = {
    'ăn': 'restaurant',
    'uống': 'restaurant',
    'cơm': 'restaurant',
    'phở': 'restaurant',
    'bún': 'restaurant',
    'mì': 'restaurant',
    'nhà hàng': 'restaurant',
    'siêu thị': 'shopping_cart',
    'chợ': 'shopping_cart',
    'mua': 'shopping_bag',
    'sắm': 'shopping_bag',
    'quần áo': 'checkroom',
    'giày': 'checkroom',
    'xe': 'directions_car',
    'grab': 'directions_car',
    'xăng': 'local_gas_station',
    'học': 'school',
    'sách': 'school',
    'khóa học': 'school',
    'phim': 'movie',
    'netflix': 'movie',
    'game': 'movie',
    'thuốc': 'medical_services',
    'bệnh viện': 'medical_services',
    'khám': 'medical_services',
    'nhà': 'home',
    'phòng': 'home',
    'trọ': 'home',
    'điện': 'electric_bolt',
    'nước': 'water_drop',
    'internet': 'wifi',
    'mạng': 'wifi',
    'gym': 'fitness_center',
    'tập': 'fitness_center',
    'thể thao': 'fitness_center',
    'cà phê': 'coffee',
    'cafe': 'coffee',
    'trà': 'coffee',
    'quà': 'card_giftcard',
    'biếu': 'card_giftcard',
    'tặng': 'card_giftcard',
    'vé': 'flight',
    'du lịch': 'flight',
    'máy bay': 'flight',
    'thú cưng': 'pets',
    'mèo': 'pets',
    'chó': 'pets',
  };
}
