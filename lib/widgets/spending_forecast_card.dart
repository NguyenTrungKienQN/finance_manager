import 'dart:math' as math;
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

        // Check if there are any transactions this month
        if (monthlyTransactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
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
                    Icons.analytics_outlined,
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
                        'Chưa có dữ liệu tháng này',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hãy thêm giao dịch để xem dự báo chi tiêu.',
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

        int daysPassed = now.day;
        if (daysPassed < 1) daysPassed = 1;

        // Smart Weighted Recency Forecasting
        double totalSpent = 0;
        double anomalyThreshold = monthlySalary * 0.15; // 15% threshold
        
        // Map daily expenditures
        Map<int, double> dailySpends = {};

        for (var t in monthlyTransactions) {
          totalSpent += t.amount;
          if (t.amount <= anomalyThreshold) {
            dailySpends[t.date.day] = (dailySpends[t.date.day] ?? 0) + t.amount;
          }
        }

        // Apply Exponential Decay Weighting
        // More recent days hold exponentially massive influence over the daily average projection.
        double weightedSum = 0;
        double totalWeight = 0;
        
        for (int day = 1; day <= daysPassed; day++) {
           int daysAgo = now.day - day;
           double weight = math.exp(-0.1 * daysAgo); // 10% memory decay per day
           double spendOnDay = dailySpends[day] ?? 0.0;
           
           weightedSum += spendOnDay * weight;
           totalWeight += weight;
        }

        double avgDailySpend = totalWeight > 0 ? (weightedSum / totalWeight).roundToDouble() : 0;
        int daysRemaining = daysInMonth - now.day;
        double projectedTotal = (totalSpent + (avgDailySpend * daysRemaining)).roundToDouble();
        double monthlyBudget = monthlySalary.roundToDouble();
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
