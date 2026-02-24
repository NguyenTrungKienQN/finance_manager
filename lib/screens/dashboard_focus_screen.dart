import 'package:flutter/material.dart';
import '../widgets/daily_balance_card.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/spending_forecast_card.dart';

class DashboardFocusScreen extends StatelessWidget {
  final double dailyLimit;
  final double monthlySalary;
  final DateTime selectedDate;

  const DashboardFocusScreen({
    super.key,
    required this.dailyLimit,
    required this.monthlySalary,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan tài chính'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DailyBalanceCard(dailyLimit: dailyLimit, selectedDate: selectedDate),
          const SizedBox(height: 16),
          WeeklySummaryCard(selectedDate: selectedDate),
          const SizedBox(height: 16),
          SpendingForecastCard(
            dailyLimit: dailyLimit,
            monthlySalary: monthlySalary,
          ),
        ],
      ),
    );
  }
}
