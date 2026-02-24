import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../services/notification_service.dart';
import '../models/transaction_model.dart';
// import '../main.dart'; // AppColors removed
import '../widgets/currency_converter_sheet.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  late Box<RecurringTransaction> _recurringBox;
  late Box<Transaction> _transactionBox;

  @override
  void initState() {
    super.initState();
    _recurringBox = Hive.box<RecurringTransaction>('recurringTransactions');
    _transactionBox = Hive.box<Transaction>('transactions');
  }

  void _addRecurring(
    String title,
    double amount,
    int dayOfMonth,
    RecurringFrequency frequency,
    int? monthOfYear,
    int interval,
  ) async {
    final newRecurring = RecurringTransaction(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      dayOfMonth: dayOfMonth,
      frequency: frequency,
      monthOfYear: monthOfYear,
      interval: interval,
    );
    await _recurringBox.add(newRecurring);

    if (newRecurring.key != null) {
      bool isYearly = frequency == RecurringFrequency.yearly;
      await NotificationService().scheduleRecurringNotification(
        id: newRecurring.key as int,
        title: 'Thanh toán ${isYearly ? "hàng năm" : "định kỳ"}: $title',
        body:
            'Đến hạn thanh toán ${NumberFormat.simpleCurrency(locale: 'vi_VN').format(amount)}',
        dayOfMonth: dayOfMonth,
        monthOfYear: monthOfYear,
        isYearly: isYearly,
        interval: interval,
      );
    }
  }

  void _markAsPaid(RecurringTransaction item) async {
    // 1. Create Transaction
    final newTx = Transaction(
      id: const Uuid().v4(),
      amount: item.amount,
      category: item.title,
      date: DateTime.now(),
      isOverBudget: false,
      notes:
          'Thanh toán ${item.frequency == RecurringFrequency.yearly ? "hàng năm" : "định kỳ"}: ${item.title}',
    );
    await _transactionBox.add(newTx);

    // 2. Update recurring item
    item.lastPaidDate = DateTime.now();
    await item.save();

    // 3. Reschedule Notification (especially for custom intervals > 1)
    if (item.key != null) {
      DateTime now = DateTime.now();
      DateTime nextDue;

      if (item.frequency == RecurringFrequency.yearly) {
        // Add interval years
        // Keep original month/day
        int targetYear = now.year + item.interval;
        // If we paid early (before due date in current year), maybe we mean current year's payment?
        // But usually mark as paid means "Done for this cycle".
        // So next due is next cycle.

        // Handle month/day logic
        int targetMonth = item.monthOfYear ?? 1;
        int targetDay = item.dayOfMonth;

        nextDue = DateTime(targetYear, targetMonth, targetDay, 9, 0);
      } else {
        // Monthly
        // Add interval months
        // Target is: (Current Month + interval)
        int targetMonth = now.month + item.interval;
        int targetYear = now.year;

        // Handle year rollover
        while (targetMonth > 12) {
          targetMonth -= 12;
          targetYear += 1;
        }

        nextDue = DateTime(targetYear, targetMonth, item.dayOfMonth, 9, 0);
      }

      // Schedule with specific date
      await NotificationService().scheduleRecurringNotification(
        id: item.key as int,
        title:
            'Thanh toán ${item.frequency == RecurringFrequency.yearly ? "hàng năm" : "định kỳ"}: ${item.title}',
        body:
            'Đến hạn thanh toán ${NumberFormat.simpleCurrency(locale: 'vi_VN').format(item.amount)}',
        dayOfMonth: item.dayOfMonth,
        monthOfYear: item.monthOfYear,
        isYearly: item.frequency == RecurringFrequency.yearly,
        interval: item.interval,
        specificDate: nextDue,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thanh toán ${item.title}'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  void _deleteRecurring(RecurringTransaction item) async {
    await NotificationService().cancelNotification(item.key as int);
    await item.delete();
  }

  void _openAddDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final intervalController = TextEditingController(text: '1');
    int selectedDay = DateTime.now().day;
    RecurringFrequency selectedFrequency = RecurringFrequency.monthly;
    int selectedMonth = DateTime.now().month; // For yearly

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
                    'Thêm khoản chi định kỳ',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Tên khoản chi',
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
                      labelText: 'Số tiền',
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

                  // Frequency & Interval Row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<RecurringFrequency>(
                          key: ValueKey(selectedFrequency),
                          value: selectedFrequency,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            labelText: 'Lặp lại',
                            labelStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
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
                          items: const [
                            DropdownMenuItem(
                              value: RecurringFrequency.monthly,
                              child: Text('Hàng tháng'),
                            ),
                            DropdownMenuItem(
                              value: RecurringFrequency.yearly,
                              child: Text('Hàng năm'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedFrequency = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: intervalController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            labelText: 'Mỗi (số)',
                            labelStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date Selection
                  Row(
                    children: [
                      Text(
                        selectedFrequency == RecurringFrequency.yearly
                            ? 'Ngày & Tháng:'
                            : 'Ngày thanh toán:',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const Spacer(),
                      // Day Dropdown
                      DropdownButton<int>(
                        value: selectedDay,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color),
                        underline: Container(),
                        items: List.generate(31, (index) => index + 1)
                            .map(
                              (day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedDay = val);
                          }
                        },
                      ),
                      // Month Dropdown (visible only if yearly)
                      if (selectedFrequency == RecurringFrequency.yearly) ...[
                        const SizedBox(width: 8),
                        Text('/',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: selectedMonth,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          underline: Container(),
                          items: List.generate(12, (index) => index + 1)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('Tháng $m'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedMonth = val);
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text;
                      final amount = double.tryParse(
                            amountController.text.replaceAll(
                              RegExp(r'[,.]'),
                              '',
                            ),
                          ) ??
                          0;
                      final interval =
                          int.tryParse(intervalController.text) ?? 1;

                      if (title.isNotEmpty && amount > 0 && interval > 0) {
                        _addRecurring(
                          title,
                          amount,
                          selectedDay,
                          selectedFrequency,
                          selectedFrequency == RecurringFrequency.yearly
                              ? selectedMonth
                              : null,
                          interval,
                        );
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
          'Định kỳ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: _recurringBox.listenable(),
        builder: (context, Box<RecurringTransaction> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có khoản chi định kỳ nào',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            );
          }

          final items = box.values.toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final now = DateTime.now();

              bool isPaid = false;
              bool isDue = false;
              String dateText = '';
              String repeatText = '';

              if (item.frequency == RecurringFrequency.yearly) {
                // Yearly Logic
                if (item.lastPaidDate != null) {
                  // Check if paid roughly this year (within interval years)
                  // Simply check if lastPaidDate is after start of current cycle year?
                  // For simplicity: check if lastPaidDate.year == now.year
                  isPaid = item.lastPaidDate!.year == now.year;
                }

                dateText = 'Ngày ${item.dayOfMonth}/${item.monthOfYear}';
                repeatText =
                    item.interval > 1 ? 'Mỗi ${item.interval} năm' : 'Hàng năm';

                DateTime dueDate = DateTime(
                  now.year,
                  item.monthOfYear!,
                  item.dayOfMonth,
                );
                if (!isPaid &&
                    now.isAfter(dueDate) &&
                    now.difference(dueDate).inDays < 30) {
                  isDue = true;
                }
              } else {
                // Monthly Logic
                if (item.lastPaidDate != null) {
                  // Logic: if current month matches lastPaidDate month?
                  // If interval > 1: check if we are within the "Paid" window?
                  // No, simple check: Did we pay *this specific instance*?
                  // If due date is this month, did we pay this month?
                  isPaid = item.lastPaidDate!.month == now.month &&
                      item.lastPaidDate!.year == now.year;

                  // If interval > 1, and we paid last month (interval index 1), and this month is skipped:
                  // Then "isPaid" is true/irrelevant?
                  // Actually, if interval > 1, we only care about due month.
                  // If this is a due month, check if paid.
                  // How to check if this is a due month?
                  // We need start date. But we don't store startDate.
                  // Using lastPaidDate as anchor.

                  // If lastPaidDate is present:
                  // Next due = lastPaidDate + interval.
                  // If now < nextDue (by month), then we are "Paid" (or waiting).
                  // If now >= nextDue (month), and not paying yet, then "Due".

                  // Better:
                  int nextMonth = item.lastPaidDate!.month + item.interval;
                  int nextYear = item.lastPaidDate!.year;
                  while (nextMonth > 12) {
                    nextMonth -= 12;
                    nextYear++;
                  }

                  if (now.year < nextYear ||
                      (now.year == nextYear && now.month < nextMonth)) {
                    isPaid = true; // Paid for current cycle
                  } else if (now.year == nextYear && now.month == nextMonth) {
                    isPaid = false; // Due this month!
                  } else {
                    isPaid = false; // Overdue
                  }
                }

                dateText = 'Ngày ${item.dayOfMonth}';
                repeatText = item.interval > 1
                    ? 'Mỗi ${item.interval} tháng'
                    : 'Hàng tháng';

                if (!isPaid && now.day >= item.dayOfMonth) {
                  // Check if strictly due this month (if interval > 1) is handled by isPaid logic above?
                  // If isPaid is false, it means we are in due month or overdue.
                  isDue = true;
                }
              }

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Theme.of(context).colorScheme.error,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) => _deleteRecurring(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: isDue
                        ? Border.all(
                            color: Theme.of(context).colorScheme.error,
                            width: 1,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1)
                              : Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPaid ? Icons.check : Icons.access_time,
                          color: isPaid
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
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
                              '$dateText • $repeatText\n${NumberFormat.simpleCurrency(locale: 'vi_VN').format(item.amount)}',
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
                      if (!isPaid)
                        IconButton(
                          onPressed: () => _markAsPaid(item),
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          tooltip: 'Đánh dấu đã trả',
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
          heroTag: 'addRecurring',
          onPressed: _openAddDialog,
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
