import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart'; // For AppTheme

class SpendingForecastCard extends StatelessWidget {
  final double dailyLimit;
  final double monthlySalary;

  const SpendingForecastCard({
    super.key,
    required this.dailyLimit,
    required this.monthlySalary,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Transaction>>(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, box, _) {
        final now = DateTime.now();
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

        // Get transactions for current month
        final monthlyTransactions = box.values.where((t) {
          return t.date.year == now.year && t.date.month == now.month;
        }).toList();

        // Calculate start date for average calculation
        int startDay = 1;

        final allTransactions = box.values.toList();

        if (allTransactions.isEmpty) {
          // New user with no data at all: Start tracking from today
          startDay = now.day;
        } else {
          // Find the very first transaction ever
          final firstEver = allTransactions
              .map((t) => t.date)
              .reduce((a, b) => a.isBefore(b) ? a : b);

          if (firstEver.year < now.year ||
              (firstEver.year == now.year && firstEver.month < now.month)) {
            // Started in previous months
            startDay = 1;
          } else {
            // Started this month
            startDay = firstEver.day;
          }
        }

        // Calculate days passed since startDay (inclusive)
        int daysPassed = now.day - startDay + 1;

        // Ensure at least 1 day to avoid division by zero
        if (daysPassed < 1) daysPassed = 1;

        // Check if there are any transactions this month
        if (monthlyTransactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF03A9F4)], // Blue gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics_outlined, // Changed icon
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chưa có dữ liệu tháng này', // "No data this month"
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hãy thêm giao dịch để xem dự báo chi tiêu.', // "Add transaction to see forecast"
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        double totalSpent = monthlyTransactions.fold(
          0,
          (sum, t) => sum + t.amount,
        );

        double avgDailySpend = totalSpent / daysPassed;

        // Days remaining in the month (after today)
        int daysRemaining = daysInMonth - now.day;

        // Projected = Total Spent + (Average * Remaining Days)
        double projectedTotal = totalSpent + (avgDailySpend * daysRemaining);

        double monthlyBudget = monthlySalary;

        bool isDanger = projectedTotal > monthlyBudget;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient:
                isDanger ? AppTheme.dangerGradient : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
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
            children: [
              // Header Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDanger ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isDanger
                          ? 'Tốc độ chi tiêu vượt mức hạn!'
                          : 'Chi tiêu trong tầm kiểm soát',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Dự kiến: ${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(projectedTotal)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Analytical Progress Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chi tiêu trung bình/ngày',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Giới hạn/ngày',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (avgDailySpend / dailyLimit).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          NumberFormat.currency(
                            locale: 'vi',
                            symbol: '₫',
                            decimalDigits: 0,
                          ).format(avgDailySpend),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'vi',
                            symbol: '₫',
                            decimalDigits: 0,
                          ).format(dailyLimit),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
