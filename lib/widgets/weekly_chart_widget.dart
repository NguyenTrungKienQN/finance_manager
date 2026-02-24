import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class WeeklyChartWidget extends StatelessWidget {
  final double dailyLimit;
  final DateTime selectedDate;

  const WeeklyChartWidget({
    super.key,
    required this.dailyLimit,
    required this.selectedDate,
  });

  List<double> _getWeeklyData(Box<Transaction> box) {
    // 1. Determine start/end of the week for selectedDate
    //    (Assuming Monday start, index 1)
    //    Weekday 1=Mon, 7=Sun
    //    Subtract (weekday - 1) days to get to Monday
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final weekStartDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEndDay = weekStartDay.add(const Duration(days: 6));
    // Actually we need to filter transactions from [weekStartDay 00:00:00] to [weekEndDay 23:59:59]

    // 2. Aggregate
    List<double> dailyTotals = List.filled(7, 0.0);

    for (var t in box.values) {
      if (t.date.isBefore(weekStartDay) ||
          t.date.isAfter(weekEndDay.add(const Duration(days: 1)))) {
        // Simple range check (ignoring time intricacies for speed, usually works if inclusive)
        // Better:
        // if t.date < weekStartDay OR t.date > end of weekEndDay
        continue;
      }

      // Double check exact date match if needed
      if (t.date.year < weekStartDay.year ||
          (t.date.year == weekStartDay.year &&
              t.date.month < weekStartDay.month) ||
          (t.date.year == weekStartDay.year &&
              t.date.month == weekStartDay.month &&
              t.date.day < weekStartDay.day)) {
        continue;
      }
      // weekStart is Monday. Diff in days:
      final diff = t.date.difference(weekStartDay).inDays;
      if (diff >= 0 && diff < 7) {
        dailyTotals[diff] += t.amount;
      }
    }
    return dailyTotals;
  }

  @override
  Widget build(BuildContext context) {
    // Soft UI Colors

    return ValueListenableBuilder<Box<Transaction>>(
      valueListenable: Hive.box<Transaction>('transactions').listenable(),
      builder: (context, box, _) {
        final weeklyData = _getWeeklyData(box);

        double maxSpend = weeklyData.isEmpty || weeklyData.every((v) => v == 0)
            ? dailyLimit
            : weeklyData.reduce((curr, next) => curr > next ? curr : next);
        if (maxSpend == 0) maxSpend = 100000; // Default scale if empty
        double maxY = maxSpend > dailyLimit ? maxSpend * 1.2 : dailyLimit * 1.2;

        int selectedDayIndex = selectedDate.weekday - 1;

        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.black87,
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    NumberFormat.currency(
                      locale: 'vi',
                      symbol: '₫',
                      decimalDigits: 0,
                    ).format(rod.toY),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                // Optional: Add interactivity
              },
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 3,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.airyBlueDark.withValues(alpha: 0.3),
                strokeWidth: 1,
                dashArray: [4, 4], // Dashed soft lines
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                    int index = value.toInt();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox();
                    }

                    bool isSelected = index == selectedDayIndex;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        children: [
                          Text(
                            days[index],
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.softPurple
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppTheme.softPurple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  reservedSize: 40,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (index) {
              double amount = weeklyData[index];
              bool isOver = amount > dailyLimit;
              bool isSelected = index == selectedDayIndex;

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: amount == 0 ? 0 : amount,
                    gradient: isOver
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF9A9E),
                              Color(0xFFFF6B6B),
                            ], // Soft Pink -> Red
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          )
                        : LinearGradient(
                            colors: isSelected
                                ? [
                                    AppTheme.softPurple,
                                    const Color(0xFF91EAE4),
                                  ] // Selected Gradient
                                : [
                                    AppTheme.softPurple.withValues(alpha: 0.3),
                                    AppTheme.softPurple.withValues(alpha: 0.5),
                                  ], // Unselected (Faded)
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                    width: isSelected ? 24 : 16,
                    borderRadius: BorderRadius.circular(8),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY, // Full height background
                      color: AppTheme.airyBlue.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}
