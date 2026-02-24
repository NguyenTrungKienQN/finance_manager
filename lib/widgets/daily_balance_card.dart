import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart'; // For AppTheme

class DailyBalanceCard extends StatelessWidget {
  final double dailyLimit;
  final DateTime selectedDate;

  const DailyBalanceCard({
    super.key,
    required this.dailyLimit,
    required this.selectedDate,
  });

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Transaction>>(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, box, _) {
        double daySpent = box.values
            .where(
              (t) =>
                  t.date.year == selectedDate.year &&
                  t.date.month == selectedDate.month &&
                  t.date.day == selectedDate.day,
            )
            .fold(0, (sum, t) => sum + t.amount);

        double remaining = dailyLimit - daySpent;
        double progress = (daySpent / dailyLimit).clamp(0.0, 1.0);
        bool isOverBudget = daySpent > dailyLimit;

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
                      'trên ${NumberFormat.compact(locale: "vi").format(dailyLimit)} hạn mức ngày',
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
  }
}
