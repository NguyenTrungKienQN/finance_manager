import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/spending_category_model.dart';
import '../services/category_registry.dart';
import '../models/settings_model.dart';
import '../utils/app_toast.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý danh mục',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ValueListenableBuilder<Box<SpendingCategory>>(
        valueListenable: Hive.box<SpendingCategory>('categories').listenable(),
        builder: (context, box, _) {
          final categories = CategoryRegistry.instance.getAll();
          final settings = Hive.box<AppSettings>('settings')
                  .get('appSettings') ?? AppSettings();
          
          final monthlyFixed = CategoryRegistry.instance.totalMonthlyFixed();
          final currentIncome = settings.totalIncomeForDate(DateTime.now());
          final dailyPool = (currentIncome - monthlyFixed) / 30; // Approximation for UI

          return Column(
            children: [
              _buildHeader(monthlyFixed, currentIncome, dailyPool),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: categories.length,
                  onReorder: (oldIdx, newIdx) async {
                    if (newIdx > oldIdx) newIdx -= 1;
                    
                    final items = List<SpendingCategory>.from(categories);
                    final item = items.removeAt(oldIdx);
                    items.insert(newIdx, item);
                    
                    // Update sortOrder locally
                    final Map<String, SpendingCategory> updates = {};
                    for (int i = 0; i < items.length; i++) {
                      items[i].sortOrder = i;
                      updates[items[i].id] = items[i];
                    }
                    
                    // Batch save to Box without triggering builder N times
                    await box.putAll(updates);
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _CategoryTile(
                      key: ValueKey(cat.id),
                      category: cat,
                      onTap: () => _editCategoryBudget(cat),
                      onDelete: cat.isDefault ? null : () => _deleteCategory(cat),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        label: const Text('Thêm danh mục'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(double monthlyFixed, double salary, double dailyPool) {
    final percent = (monthlyFixed / salary).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Cố định hàng tháng',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  '${_fmt.format(monthlyFixed.toInt())}₫ / ${_fmt.format(salary.toInt())}₫',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Ngân sách ngày', '${_fmt.format(dailyPool.toInt())}₫')),
              const SizedBox(width: 16),
              Expanded(child: _buildStatItem('Phân bổ', '${_fmt.format(CategoryRegistry.instance.totalDailyAllocated().toInt())}₫')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _addCategory() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm danh mục mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên, ví dụ: Thuê nhà, Gym...',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await CategoryRegistry.instance.addCustomCategory(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _editCategoryBudget(SpendingCategory cat) {
    final amountController = TextEditingController(
      text: cat.budget != null ? cat.budget!.toInt().toString() : '',
    );
    BudgetPeriod selectedPeriod = cat.budgetPeriod ?? BudgetPeriod.daily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(cat.colorValue).withValues(alpha: 0.1),
                    child: Icon(CategoryRegistry.instance.getIcon(cat.name), color: Color(cat.colorValue)),
                  ),
                  const SizedBox(width: 16),
                  Text(cat.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Hạn mức chi tiêu', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: '₫ ',
                  hintText: 'Để trống nếu không đặt hạn mức',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Chu kỳ hạn mức', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPeriodOption(
                    'Ngày',
                    BudgetPeriod.daily,
                    selectedPeriod,
                    () => setModalState(() => selectedPeriod = BudgetPeriod.daily),
                  ),
                  const SizedBox(width: 12),
                  _buildPeriodOption(
                    'Tháng',
                    BudgetPeriod.monthly,
                    selectedPeriod,
                    () => setModalState(() => selectedPeriod = BudgetPeriod.monthly),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    cat.budget = amount;
                    cat.budgetPeriod = amount != null ? selectedPeriod : null;
                    cat.save();
                    Navigator.pop(context);
                    if (context.mounted) {
                      AppToast.show(context, 'Đã lưu thay đổi cho ${cat.name}');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String label, BudgetPeriod period, BudgetPeriod selected, VoidCallback onTap) {
    final isSelected = period == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _deleteCategory(SpendingCategory cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Bạn có chắc muốn xóa danh mục "${cat.name}"? Các giao dịch cũ vẫn sẽ giữ tên danh mục này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              CategoryRegistry.instance.deleteCategory(cat.id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final SpendingCategory category;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'vi_VN');
    final budgetStr = category.budget != null 
        ? '${fmt.format(category.budget!.toInt())}₫/${category.budgetPeriod == BudgetPeriod.daily ? 'ngày' : 'tháng'}'
        : 'Không có hạn mức';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Color(category.colorValue).withValues(alpha: 0.1),
                child: Icon(CategoryRegistry.instance.getIcon(category.name), color: Color(category.colorValue), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budgetStr,
                      style: TextStyle(
                        color: category.budget != null 
                            ? Theme.of(context).primaryColor 
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
