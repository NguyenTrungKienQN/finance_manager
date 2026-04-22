import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/income_record_model.dart';
import '../services/income_service.dart';
import '../utils/app_toast.dart';

class IncomeManagerScreen extends StatefulWidget {
  const IncomeManagerScreen({super.key});

  @override
  State<IncomeManagerScreen> createState() => _IncomeManagerScreenState();
}

class _IncomeManagerScreenState extends State<IncomeManagerScreen> {
  DateTime _displayMonth = DateTime.now();
  final _currencyFormat = NumberFormat.simpleCurrency(locale: 'vi_VN', decimalDigits: 0);

  void _changeMonth(int months) {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + months, 1);
    });
  }

  void _showAddEditDialog([IncomeRecord? record]) {
    final nameController = TextEditingController(text: record?.name ?? '');
    final amountController = TextEditingController(text: record?.amount.toStringAsFixed(0) ?? '');
    bool isRecurring = record?.isRecurring ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(record == null ? 'Thêm thu nhập' : 'Sửa thu nhập', style: Theme.of(ctx).textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên nguồn thu (VD: Lương chính)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Lặp lại hàng tháng')),
                  Switch.adaptive(
                    value: isRecurring,
                    onChanged: (val) => setDialogState(() => isRecurring = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text) ?? 0;
                if (name.isEmpty || amount <= 0) {
                  AppToast.show(context, 'Vui lòng nhập đầy đủ thông tin');
                  return;
                }

                if (record == null) {
                  final newRecord = IncomeRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    month: _displayMonth.month,
                    year: _displayMonth.year,
                    name: name,
                    amount: amount,
                    isRecurring: isRecurring,
                  );
                  await IncomeService.instance.addIncome(newRecord);
                } else {
                  record.name = name;
                  record.amount = amount;
                  record.isRecurring = isRecurring;
                  await IncomeService.instance.updateIncome(record);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomes = IncomeService.instance.getIncomesForMonth(_displayMonth.year, _displayMonth.month);
    final total = incomes.fold(0.0, (sum, r) => sum + r.amount);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Quản lý thu nhập', style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: theme.iconTheme.color,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Month Selector Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    color: theme.primaryColor,
                  ),
                  Text(
                    DateFormat('MMMM, yyyy', 'vi_VN').format(_displayMonth),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    color: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),

          // Income List
          Expanded(
            child: incomes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: theme.dividerColor),
                        const SizedBox(height: 16),
                        Text('Chưa có nguồn thu nào trong tháng này', style: TextStyle(color: theme.dividerColor)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: incomes.length,
                    itemBuilder: (context, index) {
                      final record = incomes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(record.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Row(
                              children: [
                                if (record.isRecurring)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.replay_rounded, size: 14, color: Colors.blueAccent),
                                  ),
                                Text(record.isRecurring ? 'Lặp lại hàng tháng' : 'Một lần'),
                              ],
                            ),
                            trailing: Text(
                              _currencyFormat.format(record.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: theme.primaryColor,
                              ),
                            ),
                            onTap: () => _showAddEditDialog(record),
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Xóa nguồn thu?'),
                                  content: Text('Bạn có chắc muốn xóa "${record.name}" không?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await IncomeService.instance.deleteIncome(record);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Total Footer
          Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tổng thu nhập', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('trong tháng', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Text(
                  _currencyFormat.format(total),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
