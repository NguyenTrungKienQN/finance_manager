import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/income_service.dart';
import '../services/category_registry.dart';
import '../theme/app_theme.dart';

enum StatisticsPeriod { today, week, month, year, custom }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.month;
  DateTimeRange _customRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  final _fmt = NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0);

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case StatisticsPeriod.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatisticsPeriod.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatisticsPeriod.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatisticsPeriod.year:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case StatisticsPeriod.custom:
        return _customRange;
    }
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.softPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.blueGrey.shade900,
              secondary: AppTheme.softPurple,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppTheme.softPurple),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedPeriod = StatisticsPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getRange();
    final totalIncome = IncomeService.instance.getTotalIncomeInRange(range.start, range.end);

    return Scaffold(
      backgroundColor: AppTheme.airyBlue,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: ValueListenableBuilder<Box<Transaction>>(
              valueListenable: Hive.box<Transaction>('transactions').listenable(),
              builder: (context, box, _) {
                final txs = box.values.where((t) => 
                  t.date.isAfter(range.start.subtract(const Duration(seconds: 1))) && 
                  t.date.isBefore(range.end.add(const Duration(seconds: 1)))
                ).toList();

                final totalSpent = txs.fold<double>(0, (sum, t) => sum + t.amount);
                final net = totalIncome - totalSpent;

                Map<String, double> catData = {};
                for (var t in txs) {
                  catData[t.category] = (catData[t.category] ?? 0) + t.amount;
                }
                final sortedCats = catData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildPeriodSelector(),
                      const SizedBox(height: 24),
                      _buildMainSummaryCard(totalSpent, totalIncome, net),
                      const SizedBox(height: 32),
                      if (txs.isNotEmpty) ...[
                        _buildSectionHeader('Phân bổ chi tiêu', Icons.pie_chart_outline),
                        _buildPieChartCard(sortedCats, totalSpent),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Chi tiết hạng mục', Icons.list_alt_rounded),
                        _buildCategoryList(sortedCats, totalSpent),
                        const SizedBox(height: 40),
                      ] else
                        _buildEmptyState(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.airyBlue,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        centerTitle: true,
        title: Text(
          'Thống kê & Báo cáo',
          style: TextStyle(
            color: Colors.blueGrey.shade900,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: Colors.blueGrey.shade900,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: StatisticsPeriod.values.length,
        itemBuilder: (context, index) {
          final p = StatisticsPeriod.values[index];
          final isSelected = _selectedPeriod == p;
          String label = "";
          switch (p) {
            case StatisticsPeriod.today: label = "Hôm nay"; break;
            case StatisticsPeriod.week: label = "Tuần"; break;
            case StatisticsPeriod.month: label = "Tháng"; break;
            case StatisticsPeriod.year: label = "Năm"; break;
            case StatisticsPeriod.custom: label = "Tùy chọn"; break;
          }

          return GestureDetector(
            onTap: () {
              if (p == StatisticsPeriod.custom) {
                _selectCustomRange();
              } else {
                setState(() => _selectedPeriod = p);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.softPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppTheme.softPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.blueGrey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainSummaryCard(double spent, double income, double net) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: AppTheme.softPurple.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'TỔNG CHI TIÊU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fmt.format(spent),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 32),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _buildSmallMetric('Thu nhập', income, Icons.keyboard_double_arrow_up_rounded, Colors.greenAccent)),
                VerticalDivider(color: Colors.white24, thickness: 1, indent: 8, endIndent: 8),
                Expanded(child: _buildSmallMetric('Số dư', net, Icons.account_balance_wallet_rounded, Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String label, double value, IconData icon, Color valColor) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: valColor.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _fmt.format(value),
                style: TextStyle(color: valColor, fontWeight: FontWeight.w800, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey.shade800),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey.shade900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(List<MapEntry<String, double>> data, double total) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 5,
              centerSpaceRadius: 65,
              startDegreeOffset: -90,
              sections: data.map((entry) {
                final color = CategoryRegistry.instance.getColor(entry.key);
                final pct = (entry.value / total * 100);
                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: '', // Titles inside segments often look cluttered
                  radius: 35,
                  badgeWidget: pct > 8 ? _buildPieBadge(pct) : null,
                  badgePositionPercentageOffset: 1.3,
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Phân bổ',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Text(
                'Hạng mục',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieBadge(double pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryList(List<MapEntry<String, double>> data, double total) {
    return Column(
      children: data.map((entry) {
        final color = CategoryRegistry.instance.getColor(entry.key);
        final icon = CategoryRegistry.instance.getIcon(entry.key);
        final pct = entry.value / total;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blueGrey.shade50, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _fmt.format(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(seconds: 1),
                          height: 6,
                          width: (MediaQuery.of(context).size.width - 130) * pct,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.6)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}% tổng chi tiêu',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20)],
            ),
            child: Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có dữ liệu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Không tìm thấy giao dịch nào trong khoảng thời gian này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
