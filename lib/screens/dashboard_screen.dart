import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../models/savings_goal_model.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/weekly_chart_widget.dart';
import '../widgets/dashboard_stack.dart';
import '../theme/app_theme.dart';
import '../models/habit_breaker_model.dart';
import '../models/recurring_transaction_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late double _dailyLimit;
  late double _monthlySalary;
  DateTime _selectedDate = DateTime.now();
  String _userName = "Bạn";

  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('group.com.therize.fmanager');
    _loadSettings();
    Hive.box<Transaction>(
      'transactions',
    ).listenable().addListener(_updateHomeWidget);
  }

  @override
  void dispose() {
    Hive.box<Transaction>(
      'transactions',
    ).listenable().removeListener(_updateHomeWidget);
    super.dispose();
  }

  void _loadSettings() {
    final settingsBox = Hive.box<AppSettings>('settings');
    AppSettings? settings = settingsBox.get('appSettings');
    if (settings == null) {
      settings = AppSettings();
      settingsBox.put('appSettings', settings);
    }
    setState(() {
      _monthlySalary = settings!.monthlySalary;
      _dailyLimit = settings.computedDailyLimit;
      _userName = settings.userName;
    });
    _updateHomeWidget();
  }

  void _updateHomeWidget() async {
    if (kIsWeb) return; // Prevent Home Widget code from executing on web
    try {
      final now = DateTime.now();
      final box = Hive.box<Transaction>('transactions');
      final allTransactions = box.values.toList();

      // === Daily Balance Data ===
      double todaySpent = allTransactions
          .where(
            (t) =>
                t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day,
          )
          .fold(0.0, (sum, t) => sum + t.amount);

      await HomeWidget.saveWidgetData<String>(
        'todaySpent',
        todaySpent.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'dailyLimit',
        _dailyLimit.toString(),
      );

      // === Weekly Summary Data ===
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weeklyTransactions = allTransactions.where((t) {
        final d = t.date;
        return !d.isBefore(
              DateTime(weekStart.year, weekStart.month, weekStart.day),
            ) &&
            !d.isAfter(now);
      }).toList();

      double weeklyTotal = weeklyTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );
      int weekDays = now.weekday;
      double weeklyAvg = weekDays > 0 ? weeklyTotal / weekDays : 0;

      // Top category
      Map<String, double> categoryTotals = {};
      for (var t in weeklyTransactions) {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount;
      }
      String topCategory = '—';
      double topCategoryAmount = 0;
      if (categoryTotals.isNotEmpty) {
        var sorted = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topCategory = sorted.first.key;
        topCategoryAmount = sorted.first.value;
      }

      // Calculate Daily Totals for Bar Chart
      List<double> dailyTotals = List.filled(7, 0.0);
      for (var t in weeklyTransactions) {
        int index = t.date.weekday - 1;
        if (index >= 0 && index < 7) {
          dailyTotals[index] += t.amount;
        }
      }
      for (int i = 0; i < 7; i++) {
        await HomeWidget.saveWidgetData<String>(
          'day$i',
          dailyTotals[i].toString(),
        );
      }

      await HomeWidget.saveWidgetData<String>(
        'weeklyTotal',
        weeklyTotal.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'weeklyAvg',
        weeklyAvg.toString(),
      );
      await HomeWidget.saveWidgetData<String>('topCategory', topCategory);
      await HomeWidget.saveWidgetData<String>(
        'topCategoryAmount',
        topCategoryAmount.toString(),
      );

      // === Forecast Data ===
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      final monthlyTransactions = allTransactions
          .where((t) => t.date.year == now.year && t.date.month == now.month)
          .toList();
      double monthlySpent = monthlyTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );
      double avgDailySpend = now.day > 0 ? monthlySpent / now.day : 0;
      int daysRemaining = daysInMonth - now.day;
      double projectedTotal = monthlySpent + (avgDailySpend * daysRemaining);
      double monthlyBudget = _monthlySalary;

      await HomeWidget.saveWidgetData<String>(
        'projectedTotal',
        projectedTotal.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'monthlyBudget',
        monthlyBudget.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'avgDailySpend',
        avgDailySpend.toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'monthlySpent',
        monthlySpent.toString(),
      );

      // === Habit Breaker Data ===
      try {
        final habitBox = Hive.box<HabitBreaker>('habitBreakers');
        final activeHabits = habitBox.values.where((h) => h.isActive).toList();

        if (activeHabits.isNotEmpty) {
          activeHabits.sort(
            (a, b) => b.currentStreak.compareTo(a.currentStreak),
          );
          final topHabit = activeHabits.first;
          await HomeWidget.saveWidgetData<String>(
            'habitName',
            topHabit.habitName,
          );
          await HomeWidget.saveWidgetData<String>(
            'habitStreak',
            topHabit.currentStreak.toString(),
          );

          String status = "Bắt đầu ngay!";
          if (topHabit.currentStreak > 21) {
            status = "Tuyệt vời! 🔥";
          } else if (topHabit.currentStreak > 7) {
            status = "Giữ vững nhé! 💪";
          } else if (topHabit.currentStreak > 0) {
            status = "Khởi đầu tốt! 🌱";
          }

          await HomeWidget.saveWidgetData<String>('habitStatus', status);
        } else {
          await HomeWidget.saveWidgetData<String>(
            'habitName',
            "Chưa có thói quen",
          );
          await HomeWidget.saveWidgetData<String>('habitStreak', "0");
          await HomeWidget.saveWidgetData<String>(
            'habitStatus',
            "Thêm mới ngay",
          );
        }
        await HomeWidget.updateWidget(
          androidName: 'HabitBreakerWidgetProvider',
          iOSName: 'HabitBreakerWidget',
        );
      } catch (e) {
        if (kDebugMode) print("Error updating habit widget: $e");
      }

      // === Savings Goal Data ===
      try {
        final goalsBox = Hive.box<SavingsGoal>('savingsGoals');
        final goals = goalsBox.values.toList();
        await HomeWidget.saveWidgetData<String>(
          'savingsGoalCount',
          goals.length.toString(),
        );
        if (goals.isNotEmpty) {
          goals.sort((a, b) {
            final pctA =
                a.targetAmount > 0 ? a.savedAmount / a.targetAmount : 0;
            final pctB =
                b.targetAmount > 0 ? b.savedAmount / b.targetAmount : 0;
            return pctB.compareTo(pctA);
          });
          final topGoal = goals.first;
          await HomeWidget.saveWidgetData<String>('topGoalName', topGoal.name);
          await HomeWidget.saveWidgetData<String>(
            'topGoalCurrent',
            topGoal.savedAmount.toString(),
          );
          await HomeWidget.saveWidgetData<String>(
            'topGoalTarget',
            topGoal.targetAmount.toString(),
          );
        } else {
          await HomeWidget.saveWidgetData<String>('topGoalName', "—");
          await HomeWidget.saveWidgetData<String>('topGoalCurrent', "0");
          await HomeWidget.saveWidgetData<String>('topGoalTarget', "0");
        }
      } catch (_) {}

      // === Quick Add Data ===
      final todayTransactions = allTransactions.where(
        (t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day,
      );
      await HomeWidget.saveWidgetData<String>(
        'todayTxCount',
        todayTransactions.length.toString(),
      );

      // === Recurring Data ===
      try {
        final recurringBox =
            Hive.box<RecurringTransaction>('recurringTransactions');
        final items = recurringBox.values.toList();

        if (items.isNotEmpty) {
          int minDays = 9999;
          RecurringTransaction? nextItem;

          for (var item in items) {
            DateTime nextDue;
            if (item.frequency == RecurringFrequency.yearly) {
              nextDue =
                  DateTime(now.year, item.monthOfYear ?? 1, item.dayOfMonth);
              if (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
                nextDue = DateTime(
                    now.year + 1, item.monthOfYear ?? 1, item.dayOfMonth);
              }
            } else {
              nextDue = DateTime(now.year, now.month, item.dayOfMonth);
              if (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
                // If the day has already passed this month, the next due is next month
                int nextMonth = now.month + 1;
                int nextYear = now.year;
                if (nextMonth > 12) {
                  nextMonth = 1;
                  nextYear++;
                }
                nextDue = DateTime(nextYear, nextMonth, item.dayOfMonth);
              }
            }

            int diffDays = nextDue
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;
            if (diffDays >= 0 && diffDays < minDays) {
              minDays = diffDays;
              nextItem = item;
            }
          }

          if (nextItem != null) {
            await HomeWidget.saveWidgetData<String>(
                'recurringTitle', nextItem.title);
            await HomeWidget.saveWidgetData<String>(
                'recurringAmount', nextItem.amount.toString());
            await HomeWidget.saveWidgetData<String>(
                'recurringDays', minDays.toString());
          }
        } else {
          await HomeWidget.saveWidgetData<String>('recurringTitle', "Chưa có");
          await HomeWidget.saveWidgetData<String>('recurringAmount', "0");
          await HomeWidget.saveWidgetData<String>('recurringDays', "0");
        }
      } catch (e) {
        if (kDebugMode) print("Error updating recurring widget: $e");
      }

      // Update all 6 widgets
      await HomeWidget.updateWidget(
          androidName: 'DailyBalanceWidgetProvider',
          iOSName: 'DailyBalanceWidget');
      await HomeWidget.updateWidget(
          androidName: 'WeeklySummaryWidgetProvider',
          iOSName: 'WeeklySummaryWidget');
      await HomeWidget.updateWidget(
          androidName: 'ForecastWidgetProvider', iOSName: 'ForecastWidget');
      await HomeWidget.updateWidget(
          androidName: 'SavingsGoalWidgetProvider',
          iOSName: 'SavingsGoalWidget');
      await HomeWidget.updateWidget(
          androidName: 'QuickAddWidgetProvider', iOSName: 'QuickAddWidget');
      await HomeWidget.updateWidget(
          androidName: 'HabitBreakerWidgetProvider',
          iOSName: 'HabitBreakerWidget');
      await HomeWidget.updateWidget(
          androidName: 'RecurringWidgetProvider', iOSName: 'RecurringWidget');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating home widget: $e');
      }
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSettingsDialog() async {
    final result = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentSalary: _monthlySalary),
      ),
    );
    if (result != null) {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      setState(() {
        _monthlySalary = result;
        _dailyLimit = result / daysInMonth;
      });
      _updateHomeWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by AppTheme or Main
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- 1. Soft Header ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Avatar / Profile Pic Placeholder
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.softPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : "U",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.softPurple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Date & Settings Controls
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeDate(-1),
                          icon: const Icon(Icons.chevron_left, size: 28),
                          color: Theme.of(context).iconTheme.color,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('d').format(_selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM').format(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.0,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_isToday)
                          IconButton(
                            onPressed: () => _changeDate(1),
                            icon: const Icon(Icons.chevron_right, size: 28),
                            color: Theme.of(context).iconTheme.color,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _showSettingsDialog,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- 2. Dashboard Cards (Card Flow) ---
            SliverToBoxAdapter(
              child: DashboardStack(
                dailyLimit: _dailyLimit,
                monthlySalary: _monthlySalary,
                selectedDate: _selectedDate,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // --- 3. Weekly Chart (Soft Container) ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(32), // Soft rounded
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng quan tuần',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: WeeklyChartWidget(
                          dailyLimit: _dailyLimit,
                          selectedDate: _selectedDate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // --- 4. Transactions List ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Giao dịch gần đây',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: ValueListenableBuilder(
                valueListenable: Hive.box<Transaction>(
                  'transactions',
                ).listenable(),
                builder: (context, box, _) {
                  var dayTransactions = box.values
                      .where(
                        (t) =>
                            t.date.year == _selectedDate.year &&
                            t.date.month == _selectedDate.month &&
                            t.date.day == _selectedDate.day,
                      )
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

                  if (dayTransactions.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: Theme.of(context).disabledColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Chưa có giao dịch",
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTransactionItem(dayTransactions[index]),
                      );
                    }, childCount: dayTransactions.length),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ), // Space for dock
          ],
        ),
      ),

      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100), // Lift above Floating Dock
        child: FloatingActionButton.extended(
          heroTag: 'fab_dashboard',
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(dailyLimit: _dailyLimit),
              ),
            );
            if (result != null && result is HabitBreaker) {
              result.resetStreak();
              _updateHomeWidget();
              if (mounted) {
                _showHabitBrokenDialog(result);
              }
            }
          },
          backgroundColor: AppTheme.softPurple,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.expressiveRadius),
          ),
          label: const Text(
            "Thêm mới",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        transaction.delete();
        _updateHomeWidget(); // Update widgets after deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xóa giao dịch'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getCategoryColor(
                transaction.category,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: _getCategoryColor(transaction.category),
              size: 24,
            ),
          ),
          title: Text(
            transaction.category,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: transaction.notes != null && transaction.notes!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    transaction.notes!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(
                  locale: 'vi',
                  symbol: '₫',
                  decimalDigits: 0,
                ).format(transaction.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
              if (transaction.isOverBudget)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Vượt hạn mức',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            // Details or Edit handling
          },
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Ăn uống':
        return Colors.orange;
      case 'Giao thông':
        return Colors.blue;
      case 'Giáo dục':
        return Colors.purple;
      case 'Giải trí':
        return Colors.pink;
      case 'Y tế':
        return Colors.red;
      case 'Mua sắm':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ăn uống':
        return Icons.restaurant_rounded;
      case 'Giao thông':
        return Icons.directions_car_rounded;
      case 'Giáo dục':
        return Icons.school_rounded;
      case 'Giải trí':
        return Icons.movie_rounded;
      case 'Y tế':
        return Icons.medical_services_rounded;
      case 'Mua sắm':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  void _showHabitBrokenDialog(HabitBreaker habit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFFFF6B6B), // Soft Red
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "💔", // Broken Heart Emoji
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 16),
                Text(
                  "OH NO!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF6B6B),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Bạn đã phá vỡ chuỗi\n${habit.habitName}!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text(
                            "TRƯỚC ĐÓ",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${habit.bestStreak}", // Showing best streak or prev streak if tracking
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.grey,
                        ),
                      ),
                      Column(
                        children: [
                          const Text(
                            "HIỆN TẠI",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B6B),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "0",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: const Color(
                        0xFFFF6B6B,
                      ).withValues(alpha: 0.5),
                    ).copyWith(elevation: WidgetStateProperty.all(8)),
                    child: const Text(
                      "MÌNH SẼ LÀM LẠI!", // "I will try again!"
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
