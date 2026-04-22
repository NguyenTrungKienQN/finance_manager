import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/settings_model.dart';
import '../models/transaction_model.dart';
import '../services/app_time_service.dart';
import '../theme/app_theme.dart'; // For AppTheme
import '../models/spending_category_model.dart';
import '../services/category_registry.dart';

class DailyBalanceCard extends StatelessWidget {
  final double dailyLimit;
  final DateTime selectedDate;

  const DailyBalanceCard({
    super.key,
    required this.dailyLimit,
    required this.selectedDate,
  });

  bool get _isToday {
    final now = AppTimeService.instance.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<AppSettings>>(
      valueListenable: Hive.box<AppSettings>('settings').listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('appSettings') ?? AppSettings();

        return ValueListenableBuilder<Box<Transaction>>(
          valueListenable: Hive.box<Transaction>('transactions').listenable(),
          builder: (context, box, _) {
            double daySpent = 0;

            for (final transaction in box.values) {
              if (transaction.date.year == selectedDate.year &&
                  transaction.date.month == selectedDate.month &&
                  transaction.date.day == selectedDate.day) {
                // EXCLUDE monthly-budgeted categories from daySpent
                // as they are already pre-subtracted from the daily limit logic
                final cat =
                    CategoryRegistry.instance.getByName(transaction.category);
                if (cat?.budgetPeriod == BudgetPeriod.monthly) {
                  continue;
                }
                daySpent += transaction.amount;
              }
            }

            final dynamicDailyLimit =
                settings.calculateDailyLimitForDate(selectedDate, box.values);
            final remaining = dynamicDailyLimit - daySpent;

            // DEBUG LOGS
            debugPrint('--- DEBUG DAILY LIMIT ---');
            debugPrint('Selected Date: $selectedDate');
            debugPrint(
                'Base Daily: ${settings.baseDailyLimitFor(selectedDate)}');
            debugPrint(
                'Total Monthly Fixed: ${CategoryRegistry.instance.totalMonthlyFixed()}');
            debugPrint('Initial Month Spent: ${settings.initialMonthSpent}');
            debugPrint(
                'Setup Month Budget: ${settings.monthlySalary - CategoryRegistry.instance.totalMonthlyFixed()}');
            debugPrint('Dynamic Daily Limit: $dynamicDailyLimit');
            debugPrint('Day Spent: $daySpent');
            debugPrint('Remaining: $remaining');

            final progress = dynamicDailyLimit > 0
                ? (daySpent / dynamicDailyLimit)
                    .clamp(0.0, 1.2) // Allow slight overflow visual
                : (daySpent > 0 ? 1.2 : 0.0);

            // It is over budget if:
            // 1. We spent more than the dynamic limit allocated for today
            // 2. OR the dynamic limit is already 0 (net debt) and we spent anything at all
            final isOverBudget = daySpent > dynamicDailyLimit ||
                (dynamicDailyLimit <= 0 && daySpent > 0);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isOverBudget
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFEF5350),
                          Color(0xFFFF9A9E),
                        ], // Soft Red -> Pink
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppTheme.cardGradient, // Soft Purple -> Blue
                borderRadius: BorderRadius.circular(32), // More rounded
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isToday
                            ? 'Hôm nay'
                            : '${selectedDate.day}/${selectedDate.month}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isOverBudget)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Vượt hạn mức',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            NumberFormat.currency(
                              locale: 'vi',
                              symbol: '₫',
                              decimalDigits: 0,
                            ).format(daySpent),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'trên ${NumberFormat.compact(locale: "vi").format(dynamicDailyLimit)} hạn mức ngày',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.black.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withValues(alpha: 0.9),
                          ),
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isOverBudget ? "Vượt quá" : "Còn lại",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi',
                              symbol: '₫',
                              decimalDigits: 0,
                            ).format(remaining.abs()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
