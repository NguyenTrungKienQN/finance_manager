import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class WeeklySummaryCard extends StatelessWidget {
  final DateTime selectedDate;

  const WeeklySummaryCard({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Transaction>>(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, box, _) {
        // Calculate start of week (Monday)
        DateTime startOfWeek = selectedDate.subtract(
          Duration(days: selectedDate.weekday - 1),
        );
        startOfWeek = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        DateTime endOfWeek = startOfWeek.add(const Duration(days: 7));

        // Filter transactions for the week
        final weeklyTransactions = box.values.where((t) {
          return t.date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              t.date.isBefore(endOfWeek);
        }).toList();

        double totalWeeklySpend = weeklyTransactions.fold(
          0,
          (sum, t) => sum + t.amount,
        );

        // Group by category
        Map<String, double> categorySpend = {};
        for (var t in weeklyTransactions) {
          categorySpend[t.category] =
              (categorySpend[t.category] ?? 0) + t.amount;
        }

        // Sort categories by spend (descending)
        var sortedCategories = categorySpend.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tuần này',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.softPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.subtract(const Duration(days: 1)).day}/${endOfWeek.month}',
                      style: const TextStyle(
                        color: AppTheme.softPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(
                  locale: 'vi',
                  symbol: '₫',
                  decimalDigits: 0,
                ).format(totalWeeklySpend),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              if (sortedCategories.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      "Chưa có chi tiêu",
                      style: TextStyle(
                        color: Theme.of(context).disabledColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: sortedCategories.take(2).map((entry) {
                    double pct = totalWeeklySpend > 0
                        ? (entry.value / totalWeeklySpend)
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          _CategoryIcon(category: entry.key),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor: AlwaysStoppedAnimation(
                                      const Color(
                                        0xFF6C63FF,
                                      ).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            NumberFormat.compact(
                              locale: "vi",
                            ).format(entry.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String category;

  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (category) {
      case 'Ăn uống':
        icon = Icons.restaurant_rounded;
        color = Colors.orangeAccent;
        break;
      case 'Giao thông':
        icon = Icons.directions_car_rounded;
        color = Colors.blueAccent;
        break;
      case 'Giáo dục':
        icon = Icons.school_rounded;
        color = Colors.purpleAccent;
        break;
      case 'Giải trí':
        icon = Icons.movie_rounded;
        color = Colors.pinkAccent;
        break;
      case 'Y tế':
        icon = Icons.medical_services_rounded;
        color = Colors.redAccent;
        break;
      case 'Mua sắm':
        icon = Icons.shopping_bag_rounded;
        color = Colors.tealAccent;
        break;
      default:
        icon = Icons.receipt_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
