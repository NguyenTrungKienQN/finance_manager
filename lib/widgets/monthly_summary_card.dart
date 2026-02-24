import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class MonthlySummaryCard extends StatelessWidget {
  final double dailyLimit;
  final double monthlySalary;

  const MonthlySummaryCard({
    super.key,
    required this.dailyLimit,
    required this.monthlySalary,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, box, _) {
        final now = DateTime.now();
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final monthlyBudget = monthlySalary;

        final monthlyTransactions = box.values
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
        final totalSpent = monthlyTransactions.fold(
          0.0,
          (sum, t) => sum + t.amount,
        );
        final remaining = monthlyBudget - totalSpent;
        final avgPerDay = now.day > 0 ? totalSpent / now.day : 0.0;
        final budgetPct = monthlyBudget > 0
            ? (totalSpent / monthlyBudget).clamp(0.0, 1.0)
            : 0.0;
        final dayPct = now.day / daysInMonth;

        // Spending pace: if budgetPct > dayPct, spending too fast
        final bool isFast = budgetPct > dayPct;

        final fmt = NumberFormat.currency(
          locale: 'vi',
          symbol: '₫',
          decimalDigits: 0,
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00695C)],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.tealAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tháng ${now.month}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Pace indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFast
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : Colors.greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFast
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : Colors.greenAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFast ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: isFast ? Colors.redAccent : Colors.greenAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFast ? 'Chi nhanh' : 'Ổn định',
                          style: TextStyle(
                            color:
                                isFast ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Main numbers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã chi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(totalSpent),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Còn lại',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(remaining.clamp(0, double.infinity)),
                        style: TextStyle(
                          color: remaining >= 0
                              ? Colors.tealAccent
                              : Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    LinearProgressIndicator(
                      value: budgetPct,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        isFast ? Colors.redAccent : Colors.tealAccent,
                      ),
                      minHeight: 6,
                    ),
                    // Day progress marker
                    Positioned(
                      left: dayPct * (MediaQuery.of(context).size.width - 80),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TB/ngày: ${fmt.format(avgPerDay)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Ngày ${now.day}/$daysInMonth',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
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
