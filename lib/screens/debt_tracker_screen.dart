import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_record_model.dart';
import '../widgets/currency_converter_sheet.dart';

class DebtTrackerScreen extends StatefulWidget {
  const DebtTrackerScreen({super.key});

  @override
  State<DebtTrackerScreen> createState() => _DebtTrackerScreenState();
}

class _DebtTrackerScreenState extends State<DebtTrackerScreen> {
  late Box<DebtRecord> _debtBox;

  @override
  void initState() {
    super.initState();
    _debtBox = Hive.box<DebtRecord>('debtRecords');
  }

  void _addDebts(
    double totalAmount,
    String description,
    List<String> people,
  ) async {
    if (people.isEmpty) return;

    // Simple split for now: Total / People
    double splitAmount = totalAmount / people.length;

    // User pays for everyone (including themselves? No, "I paying all fees and I save **their** debits")
    // If I pay 300k for 3 people (Me + A + B). I pay 300k.
    // A owes 100k. B owes 100k. I owe myself 100k (ignored).
    // The user input "how many people and their debits".
    // Usually user inputs "How many people involved" and "Who they are".
    // If I am involved, I select "Me".
    // If 3 people (A, B, Me). Total 300.
    // A owes 100. B owes 100.
    // Me pays 300.

    // Current simple logic: User inputs "Who owes me".
    // If user inputs "A, B".
    // And Total Amount "200k".
    // Then A owes 100, B owes 100.
    // Or did user mean "Total Bill was 300k including me"?
    // "when i buy something... input how many people and their debits".
    // Let's assume user enters the list of DEBTORS.
    // And the amount they owe.
    // Or Total Amount to split among them.

    for (String person in people) {
      final debt = DebtRecord(
        id: const Uuid().v4(),
        debtorName: person,
        amount: splitAmount,
        description: description,
        date: DateTime.now(),
        isPaid: false,
      );
      await _debtBox.add(debt);
    }
  }

  void _markAsPaid(DebtRecord debt) async {
    // User said "tick ok and it will delete the debits"
    // I will delete it. Alternatively, mark isPaid=true and keep history?
    // User explicitly said "delete".
    await debt.delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${debt.debtorName} đã trả tiền'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  void _showAddDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    // List of people names
    List<TextEditingController> peopleControllers = [TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Thêm khoản nợ',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: descController,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Nội dung (VD: Ăn trưa)',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Tổng tiền cần chia',
                      labelStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      suffixText: 'đ',
                      suffixIcon: IconButton(
                        onPressed: () {
                          CurrencyConverterSheet.show(
                            context,
                            targetController: amountController,
                          );
                        },
                        icon: Icon(
                          Icons.currency_exchange,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        tooltip: 'Quy đổi tiền tệ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Người nợ:',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dynamic list of people inputs
                  ...peopleControllers.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color),
                              decoration: InputDecoration(
                                hintText: 'Tên người ${idx + 1}',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.3),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          if (peopleControllers.length > 1)
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  peopleControllers.removeAt(idx);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),

                  TextButton.icon(
                    onPressed: () {
                      setModalState(() {
                        peopleControllers.add(TextEditingController());
                      });
                    },
                    icon: Icon(
                      Icons.add,
                      color: Theme.of(context).primaryColor,
                    ),
                    label: Text(
                      'Thêm người',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final desc = descController.text;
                      final amount = double.tryParse(
                            amountController.text.replaceAll(
                              RegExp(r'[,.]'),
                              '',
                            ),
                          ) ??
                          0;
                      final people = peopleControllers
                          .map((c) => c.text.trim())
                          .where((name) => name.isNotEmpty)
                          .toList();

                      if (desc.isNotEmpty && amount > 0 && people.isNotEmpty) {
                        _addDebts(amount, desc, people);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Sổ nợ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: _debtBox.listenable(),
        builder: (context, Box<DebtRecord> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có khoản nợ nào',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            );
          }

          final items = box.values.toList();
          // Group by person? Or just list?
          // List is fine for now.

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Theme.of(context).primaryColor,
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                onDismissed: (direction) => _markAsPaid(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.debtorName,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.description} • ${DateFormat('dd/MM').format(item.date)}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        NumberFormat.simpleCurrency(
                          locale: 'vi_VN',
                        ).format(item.amount),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.check_box_outline_blank,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        onPressed: () => _markAsPaid(item),
                        tooltip: 'Đã trả',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton(
          heroTag: 'addDebt',
          onPressed: _showAddDialog,
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
