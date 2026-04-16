import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

// ============================================================
// DESIGN TOKENS — Premium Widget Language
// ============================================================

final _fmt = NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0);

// ============================================================
// 1. DAILY BALANCE — Deep Blue Card
// ============================================================
class DailyBalanceHomeWidget extends StatelessWidget {
  final double spent;
  final double limit;

  const DailyBalanceHomeWidget({Key? key, required this.spent, required this.limit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remaining = limit - spent;
    final isOver = remaining < 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isOver
              ? [const Color(0xFFE53935), const Color(0xFFB71C1C), const Color(0xFF880E0E)]
              : [const Color(0xFF4A7CF7), const Color(0xFF3355CC), const Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Diagonal light streak
          Positioned(
            top: -30,
            right: -10,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 80,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SỐ DƯ HÔM NAY', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    if (isOver)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Vượt', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                // MASSIVE hero number
                Text(
                  _fmt.format(remaining),
                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.0),
                ),
                // Bottom info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đã chi: ${_fmt.format(spent)}', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
                    Text('Hạn mức: ${_fmt.format(limit)}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 2. WEEKLY SUMMARY — Dark Analytics
// ============================================================
class WeeklySummaryHomeWidget extends StatelessWidget {
  final double weeklyTotal;
  final double dailyAverage;

  const WeeklySummaryHomeWidget({Key? key, required this.weeklyTotal, required this.dailyAverage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bars = [0.4, 0.7, 0.5, 0.9, 0.6, 0.3, 0.75];
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const barColor = Color(0xFFFFB74D); // Warm amber — ONE color

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF151528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Warm amber glow behind chart area
          Positioned(
            bottom: 20,
            left: 40,
            child: Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: barColor.withOpacity(0.12), blurRadius: 40, spreadRadius: 10)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THỐNG KÊ TUẦN', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(
              _fmt.format(weeklyTotal),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1),
            ),
            const Spacer(),
            // Bar chart — uniform amber
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: bars[i],
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor.withOpacity(0.6 + bars[i] * 0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(dayLabels[i], style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Text('TB: ${_fmt.format(dailyAverage)} / ngày', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
          ],
        ),
        ),
      ]),
    );
  }
}

// ============================================================
// 3. FORECAST — Warm Coral/Orange
// ============================================================
class ForecastHomeWidget extends StatelessWidget {
  final double projectedTotal;
  final double monthlyBudget;
  final double avgDailySpend;

  const ForecastHomeWidget({Key? key, required this.projectedTotal, required this.monthlyBudget, required this.avgDailySpend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDanger = projectedTotal > monthlyBudget;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDanger
              ? [const Color(0xFFFF6B4A), const Color(0xFFFF4114), const Color(0xFFCC3300)]
              : [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Faint curved line
          Positioned.fill(
            child: CustomPaint(painter: _SubtleCurvePainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DỰ BÁO', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        isDanger ? '↑ Vượt chi' : '✓ Ổn',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Text(
                  _fmt.format(projectedTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.0),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('NS: ${_fmt.format(monthlyBudget)}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    Text('${_fmt.format(avgDailySpend)}/ngày', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. SAVINGS GOAL — Dark + Green Glow
// ============================================================
class SavingsGoalHomeWidget extends StatelessWidget {
  final String topGoalName;
  final double goalCurrent;
  final double goalTarget;
  final int goalCount;

  const SavingsGoalHomeWidget({Key? key, required this.topGoalName, required this.goalCurrent, required this.goalTarget, required this.goalCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = goalTarget > 0 ? (goalCurrent / goalTarget).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();
    const green = Color(0xFF34D399);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF151528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Green glow behind progress area
          Positioned(
            bottom: 10,
            left: 16,
            child: Container(
              width: 200,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: green.withOpacity(0.25), blurRadius: 20, spreadRadius: 2)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(topGoalName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('$pct%', style: const TextStyle(color: green, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                // Big number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmt.format(goalCurrent),
                      style: const TextStyle(color: green, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.0),
                    ),
                    const SizedBox(width: 4),
                    Text('/ ${_fmt.format(goalTarget)}', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                  ],
                ),
                // Progress bar with glow
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [BoxShadow(color: green.withOpacity(0.5), blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 5. QUICK ADD — Dark Teal (Square)
// ============================================================
class QuickAddHomeWidget extends StatelessWidget {
  final double todaySpent;
  final int txCount;

  const QuickAddHomeWidget({Key? key, required this.todaySpent, required this.txCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B4F), Color(0xFF0A2A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle glow
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.15), blurRadius: 25)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // + icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.white.withOpacity(0.8), size: 18),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt.format(todaySpent),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.0),
                    ),
                    const SizedBox(height: 3),
                    Text('$txCount giao dịch', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 6. HABIT BREAKER — Warm Pink/Purple (Square)
// ============================================================
class HabitBreakerHomeWidget extends StatelessWidget {
  final String habitName;
  final int streak;
  final String status;

  const HabitBreakerHomeWidget({Key? key, required this.habitName, required this.streak, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B4E), Color(0xFF1A1028)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Fire glow
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFFFF6B4A).withOpacity(0.3), blurRadius: 20)],
              ),
              child: Center(child: Text('🔥', style: const TextStyle(fontSize: 14))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(habitName, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streak',
                          style: const TextStyle(color: Color(0xFFF472B6), fontSize: 52, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2),
                        ),
                        const SizedBox(width: 3),
                        Text('ngày', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 7. RECURRING — Dark Matte List Style
// ============================================================
class RecurringHomeWidget extends StatelessWidget {
  final String title;
  final double amount;
  final int daysUntilDue;

  const RecurringHomeWidget({Key? key, required this.title, required this.amount, required this.daysUntilDue}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysUntilDue <= 3;
    const blue = Color(0xFF4FACFE);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF151528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Blue glow
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: blue.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
            ),
          ),
          Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('THANH TOÁN ĐỊNH KỲ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
            // Card within card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_rounded, color: blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_fmt.format(amount), style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                      ],
                    ),
                  ),
                  // Days badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUrgent ? const Color(0xFFFF6B4A).withOpacity(0.15) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dueLabel(),
                      style: TextStyle(
                        color: isUrgent ? const Color(0xFFFF6B4A) : Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Timeline dots
            Row(
              children: List.generate(7, (i) {
                final filled = i < (7 - daysUntilDue.clamp(0, 7));
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: filled ? blue.withOpacity(0.7) : Colors.white.withOpacity(0.08),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        ),
      ]),
    );
  }

  String _dueLabel() {
    if (daysUntilDue < 0) return '${daysUntilDue.abs()}d trễ';
    if (daysUntilDue == 0) return 'Hôm nay';
    return '${daysUntilDue}d';
  }
}

// ============================================================
// HELPER PAINTERS
// ============================================================
class _SubtleCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.6, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.65, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
