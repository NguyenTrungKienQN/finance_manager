import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  const DailyBalanceHomeWidget(
      {super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    final remaining = limit - spent;
    final isOver = remaining < 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isOver
              ? [
                  const Color(0xFFE53935),
                  const Color(0xFFB71C1C),
                  const Color(0xFF880E0E)
                ]
              : [
                  const Color(0xFF4A7CF7),
                  const Color(0xFF3355CC),
                  const Color(0xFF1A237E)
                ],
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
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.0)
                    ],
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
                    Text('SỐ DƯ HÔM NAY',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    if (isOver)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Vượt',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                // MASSIVE hero number
                Text(
                  _fmt.format(remaining),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1.0),
                ),
                // Bottom info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đã chi: ${_fmt.format(spent)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10)),
                    Text('Hạn mức: ${_fmt.format(limit)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10)),
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

// ============================================================
// 3. FORECAST — Warm Coral/Orange
// ============================================================
class ForecastHomeWidget extends StatelessWidget {
  final double projectedTotal;
  final double monthlyBudget;
  final double avgDailySpend;

  const ForecastHomeWidget(
      {super.key,
      required this.projectedTotal,
      required this.monthlyBudget,
      required this.avgDailySpend});

  @override
  Widget build(BuildContext context) {
    final isDanger = projectedTotal > monthlyBudget;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDanger
              ? [
                  const Color(0xFFFF6B4A),
                  const Color(0xFFFF4114),
                  const Color(0xFFCC3300)
                ]
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
                    Text('DỰ BÁO',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        isDanger ? '↑ Vượt chi' : '✓ Ổn',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Text(
                  _fmt.format(projectedTotal),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1.0),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('NS: ${_fmt.format(monthlyBudget)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10)),
                    Text('${_fmt.format(avgDailySpend)}/ngày',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10)),
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

// ============================================================
// 5. QUICK ADD — Dark Teal (Square)
// ============================================================
class QuickAddHomeWidget extends StatelessWidget {
  final double todaySpent;
  final int txCount;

  const QuickAddHomeWidget(
      {super.key, required this.todaySpent, required this.txCount});

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
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4FACFE).withValues(alpha: 0.15),
                      blurRadius: 25)
                ],
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
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_rounded,
                      color: Colors.white.withValues(alpha: 0.8), size: 18),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt.format(todaySpent),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1.0),
                    ),
                    const SizedBox(height: 3),
                    Text('$txCount giao dịch',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 9)),
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

  const HabitBreakerHomeWidget(
      {super.key,
      required this.habitName,
      required this.streak,
      required this.status});

  @override
  Widget build(BuildContext context) {
    final accentColor = status.contains('🧊')
        ? const Color(0xFF7DD3FC)
        : status.contains('✨')
            ? const Color(0xFFC084FC)
            : const Color(0xFFF472B6);
    final heroEmoji = status.contains('🧊')
        ? '🧊'
        : status.contains('🛡️')
            ? '🛡️'
            : status.contains('✨')
                ? '💜'
                : '🔥';

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
                boxShadow: [
                  BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 20)
                ],
              ),
              child: Center(
                  child: Text(heroEmoji, style: const TextStyle(fontSize: 14))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(habitName,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streak',
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -2),
                        ),
                        const SizedBox(width: 3),
                        Text('ngày',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

// ============================================================
// HELPER PAINTERS
// ============================================================
class _SubtleCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.3, size.width * 0.6,
          size.height * 0.5)
      ..quadraticBezierTo(
          size.width * 0.8, size.height * 0.65, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
