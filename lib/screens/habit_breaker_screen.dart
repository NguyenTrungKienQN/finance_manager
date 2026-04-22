import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit_breaker_model.dart';
import '../services/app_time_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_broken_dialog.dart';
import '../utils/app_toast.dart';
import '../services/gemini_chat_service.dart';
import '../utils/habit_helper.dart';

class HabitBreakerScreen extends StatefulWidget {
  const HabitBreakerScreen({super.key});

  @override
  State<HabitBreakerScreen> createState() => _HabitBreakerScreenState();
}

class _HabitBreakerScreenState extends State<HabitBreakerScreen> {
  @override
  void initState() {
    super.initState();
    AppTimeService.instance.overrideNotifier.addListener(_handleTimeOverride);
    _advanceAllStreaks();
  }

  @override
  void dispose() {
    AppTimeService.instance.overrideNotifier
        .removeListener(_handleTimeOverride);
    super.dispose();
  }

  void _handleTimeOverride() {
    if (!mounted) return;
    _advanceAllStreaks();
    setState(() {});
  }

  void _advanceAllStreaks() {
    final box = Hive.box<HabitBreaker>('habitBreakers');
    final recoveredHabits = <String>[];

    for (final habit in box.values) {
      if (!habit.isActive) continue;

      habit.ensureBackwardCompatibility();
      final wasFrozen = habit.isFrozen;
      final previousStreak = habit.currentStreak;
      habit.advanceStreak();

      if (wasFrozen && !habit.isFrozen) {
        NotificationService().fireStreakRecovered(habit);
        recoveredHabits.add(
          'Hồi phục thành công: "${habit.habitName}" giữ được chuỗi $previousStreak ngày.',
        );
      }
    }

    if (!mounted || recoveredHabits.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final message in recoveredHabits) {
        AppToast.show(context, message);
      }
    });
  }

  static const Map<String, Map<String, String>> badgeInfo = {
    'starter': {'label': 'Khởi đầu', 'emoji': '🌱', 'days': '3'},
    'warrior': {'label': 'Chiến binh', 'emoji': '⚔️', 'days': '7'},
    'persistent': {'label': 'Bền bỉ', 'emoji': '💪', 'days': '14'},
    'legend': {'label': 'Huyền thoại', 'emoji': '🏆', 'days': '30'},
  };


  void _showBadgeDialog(HabitBreaker habit, String badgeId) {
    final badge = badgeInfo[badgeId]!;
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge['emoji']!, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                'Huy hiệu: ${badge['label']}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Đạt được sau ${badge['days']} ngày kiên trì!',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tuyệt vời!',
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRelapseOutcome(
    HabitBreaker habit,
    RelapseResult result, {
    required int lostStreak,
  }) async {
    if (result == RelapseResult.fullReset) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_broken_habit_id', habit.id);
      await prefs.setString(
        'last_broken_time',
        AppTimeService.instance.now().toIso8601String(),
      );

      if (!mounted) return;
      await showFullResetDialog(
        context,
        habitName: habit.habitName,
        lostStreak: lostStreak,
      );
      return;
    }

    if (!mounted) return;

    if (result == RelapseResult.shieldAbsorbed) {
      await showShieldAbsorbedDialog(context, habitName: habit.habitName);
      return;
    }

    await NotificationService().fireStreakFrozen(habit);
    if (!mounted) return;
    await showStreakFrozenDialog(context, habitName: habit.habitName);
  }

  void _confirmRelapse(HabitBreaker habit) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Xác nhận',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Text(
            'Bạn đã chi tiêu cho "${habit.habitName}" hôm nay?',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Không, tôi vẫn giữ được!',
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
            TextButton(
              onPressed: () async {
                final previousStreak = habit.currentStreak;
                Navigator.pop(ctx);
                final result = habit.handleRelapse();
                await _handleRelapseOutcome(
                  habit,
                  result,
                  lostStreak: previousStreak,
                );
              },
              child: Text(
                'Vâng, tôi đã mua...',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteHabit(HabitBreaker habit) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Xóa thử thách',
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Text(
            'Bạn có chắc muốn xóa "${habit.habitName}"?',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            TextButton(
              onPressed: () {
                habit.delete();
                Navigator.pop(ctx);
              },
              child: Text(
                'Xóa',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAiSuggestion() async {
    AppToast.show(context, 'Đang phân tích chi tiêu...');
    final suggestion = await GeminiChatService().suggestHabitChallenge();
    if (!mounted) return;

    if (suggestion == null) {
      AppToast.show(context, 'Bạn đang chi tiêu rất tốt, chưa tìm thấy thói quen xấu nổi bật nào!');
      return;
    }

    HabitHelper.showAiSuggestionDialog(context, suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<HabitBreaker>>(
          valueListenable: Hive.box<HabitBreaker>('habitBreakers').listenable(),
          builder: (context, box, _) {
            final habits = box.values.toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: theme.primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thử thách bỏ thói quen',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _handleAiSuggestion,
                          icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                          tooltip: 'AI Gợi ý',
                        ),
                      ],
                    ),
                  ),
                ),
                if (habits.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildHabitCard(habits[index], theme),
                        );
                      }, childCount: habits.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          heroTag: 'addHabit',
          onPressed: () => HabitHelper.showAddHabitSheet(context),
          backgroundColor: theme.primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Thêm',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có thử thách nào',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Bắt đầu bỏ một thói quen xấu ngay hôm nay!',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHabitCard(HabitBreaker habit, ThemeData theme) {
    final streakColor = _streakColorFor(habit, theme);
    final statusColor = _statusColorFor(habit, theme);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: streakColor.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (habit.isFrozen) _buildFreezeBanner(habit),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStreakArt(habit, streakColor, theme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.habitName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kỷ lục: ${habit.bestStreak} ngày',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          habit.getStatusText(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      _streakEmojiFor(habit),
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      '${habit.currentStreak}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: streakColor,
                      ),
                    ),
                    Text(
                      'ngày',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStreakCalendar(habit, theme, streakColor),
          ),
          if (habit.badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Huy hiệu: ',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  ...habit.badges.map((badgeId) {
                    final badge = badgeInfo[badgeId];
                    if (badge == null) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => _showBadgeDialog(habit, badgeId),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: badge['label']!,
                          child: Text(
                            badge['emoji']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _deleteHabit(habit),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.textTheme.bodyMedium?.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmRelapse(habit),
                  icon: Icon(
                    Icons.sentiment_dissatisfied,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                  label: Text(
                    'Tôi đã mua...',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
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

  Widget _buildFreezeBanner(HabitBreaker habit) {
    final remaining = habit.freezeDaysRemaining;
    final text = remaining > 0
        ? '🧊 Chuỗi đóng băng · Còn $remaining ngày để hồi phục'
        : '🧊 Hồi phục thành công!';
    final colors = habit.showsPurpleFrozenState
        ? [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)]
        : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }

  Widget _buildStreakArt(
    HabitBreaker habit,
    Color streakColor,
    ThemeData theme,
  ) {
    final assetPath = _streakAssetFor(habit);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 74,
        height: 74,
        color: streakColor.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildStreakArtFallback(habit, streakColor, theme),
        ),
      ),
    );
  }

  Widget _buildStreakArtFallback(
    HabitBreaker habit,
    Color streakColor,
    ThemeData theme,
  ) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: streakColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(HabitHelper.getIcon(habit.iconName), color: streakColor, size: 28),
          if (habit.hasActiveShield)
            Positioned(
              right: 6,
              bottom: 6,
              child: Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.secondary,
                size: 18,
              ),
            )
          else if (habit.isFrozen)
            const Positioned(
              right: 6,
              bottom: 6,
              child: Icon(Icons.ac_unit, color: Color(0xFF1E88E5), size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar(
    HabitBreaker habit,
    ThemeData theme,
    Color streakColor,
  ) {
    final now = AppTimeService.instance.now();
    final today = DateTime(now.year, now.month, now.day);
    final fallbackCleanDays = _fallbackCleanDays(habit, today);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final state = habit.dayStateFor(day);
        final derivedState = state ?? fallbackCleanDays[day];
        final isToday = day == today;
        final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        final dayName = dayNames[day.weekday - 1];
        final style = _calendarStyleFor(
          derivedState,
          streakColor,
          theme,
          isToday: isToday,
        );

        return Column(
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 10,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: style.background,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: style.border ?? streakColor, width: 2)
                    : style.border != null
                        ? Border.all(color: style.border!, width: 1.4)
                        : null,
              ),
              child: Center(
                child: style.icon != null
                    ? Icon(style.icon, color: style.foreground, size: 18)
                    : Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.foreground,
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Map<DateTime, String> _fallbackCleanDays(HabitBreaker habit, DateTime today) {
    if (habit.dayStates.isNotEmpty ||
        habit.currentStreak <= 0 ||
        habit.isFrozen) {
      return const {};
    }

    final fallback = <DateTime, String>{};
    final days = habit.currentStreak > 7 ? 7 : habit.currentStreak;
    for (var offset = 0; offset < days; offset++) {
      final day = today.subtract(Duration(days: offset));
      fallback[DateTime(day.year, day.month, day.day)] = 'clean';
    }
    return fallback;
  }

  _CalendarStyle _calendarStyleFor(
    String? state,
    Color streakColor,
    ThemeData theme, {
    required bool isToday,
  }) {
    switch (state) {
      case 'upgrade':
        return _CalendarStyle(
          background: const Color(0xFFEDE7F6),
          foreground: const Color(0xFF6A1B9A),
          icon: Icons.auto_awesome_rounded,
          border: const Color(0xFFAB47BC),
        );
      case 'shield_used':
        return _CalendarStyle(
          background: const Color(0xFFFFF3E0),
          foreground: const Color(0xFFEF6C00),
          icon: Icons.shield_outlined,
          border: const Color(0xFFFFB74D),
        );
      case 'frozen':
        return _CalendarStyle(
          background: const Color(0xFFE3F2FD),
          foreground: const Color(0xFF1E88E5),
          icon: Icons.ac_unit,
          border: const Color(0xFF90CAF9),
        );
      case 'reset':
        return _CalendarStyle(
          background: const Color(0xFFFFEBEE),
          foreground: const Color(0xFFE53935),
          icon: Icons.close_rounded,
          border: const Color(0xFFEF9A9A),
        );
      case 'clean':
        return _CalendarStyle(
          background: streakColor.withValues(alpha: 0.2),
          foreground: streakColor,
          icon: Icons.check,
        );
      default:
        return _CalendarStyle(
          background: theme.canvasColor,
          foreground: theme.textTheme.bodyMedium?.color ?? Colors.grey,
          border: isToday ? streakColor : null,
        );
    }
  }

  Color _streakColorFor(HabitBreaker habit, ThemeData theme) {
    if (habit.isFrozen) {
      return habit.showsPurpleFrozenState
          ? const Color(0xFF7E57C2)
          : const Color(0xFF42A5F5);
    }
    if (habit.hasActiveShield) {
      return const Color(0xFF6A1B9A);
    }
    if (habit.isPurpleWithoutShield) {
      return const Color(0xFF8E24AA);
    }
    if (habit.currentStreak >= 30) {
      return const Color(0xFFFFD700);
    }
    if (habit.currentStreak >= 14) {
      return const Color(0xFFFF6B35);
    }
    if (habit.currentStreak >= 7) {
      return const Color(0xFFFF9800);
    }
    if (habit.currentStreak >= 3) {
      return const Color(0xFFFFC107);
    }
    return theme.primaryColor;
  }

  Color _statusColorFor(HabitBreaker habit, ThemeData theme) {
    if (habit.isFrozen) {
      return habit.showsPurpleFrozenState
          ? const Color(0xFF5E35B1)
          : const Color(0xFF1E88E5);
    }
    if (habit.isPurpleTier) {
      return const Color(0xFF7B1FA2);
    }
    return theme.textTheme.bodyMedium?.color ?? theme.primaryColor;
  }

  String _streakAssetFor(HabitBreaker habit) {
    if (habit.isFrozen) {
      return habit.showsPurpleFrozenState
          ? 'assets/streak/streak_frozen_purple.png'
          : 'assets/streak/streak_frozen_regular.png';
    }
    if (habit.hasActiveShield) {
      return 'assets/streak/streak_purple_shield.png';
    }
    if (habit.isPurpleTier) {
      return 'assets/streak/streak_purple.png';
    }
    return 'assets/streak/streak_regular.png';
  }

  String _streakEmojiFor(HabitBreaker habit) {
    if (habit.isFrozen) return '🧊';
    if (habit.hasActiveShield) return '🛡️';
    if (habit.isPurpleTier) return '💜';
    return '🔥';
  }
}

class _CalendarStyle {
  const _CalendarStyle({
    required this.background,
    required this.foreground,
    this.icon,
    this.border,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? border;
}
