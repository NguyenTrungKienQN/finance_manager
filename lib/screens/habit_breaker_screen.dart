import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_breaker_model.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class HabitBreakerScreen extends StatefulWidget {
  const HabitBreakerScreen({super.key});

  @override
  State<HabitBreakerScreen> createState() => _HabitBreakerScreenState();
}

class _HabitBreakerScreenState extends State<HabitBreakerScreen> {
  @override
  void initState() {
    super.initState();
    // Advance all streaks on screen open
    _advanceAllStreaks();
  }

  void _advanceAllStreaks() {
    final box = Hive.box<HabitBreaker>('habitBreakers');
    for (var habit in box.values) {
      if (habit.isActive) {
        habit.advanceStreak();
      }
    }
  }

  // Badge metadata
  static const Map<String, Map<String, String>> badgeInfo = {
    'starter': {'label': 'Khởi đầu', 'emoji': '🌱', 'days': '3'},
    'warrior': {'label': 'Chiến binh', 'emoji': '⚔️', 'days': '7'},
    'persistent': {'label': 'Bền bỉ', 'emoji': '💪', 'days': '14'},
    'legend': {'label': 'Huyền thoại', 'emoji': '🏆', 'days': '30'},
  };

  // Icon picker options
  static const Map<String, IconData> iconOptions = {
    'local_cafe': Icons.local_cafe,
    'local_bar': Icons.local_bar,
    'smoking_rooms': Icons.smoking_rooms,
    'shopping_bag': Icons.shopping_bag,
    'fastfood': Icons.fastfood,
    'sports_esports': Icons.sports_esports,
    'phone_android': Icons.phone_android,
    'cake': Icons.cake,
    'icecream': Icons.icecream,
    'wine_bar': Icons.wine_bar,
  };

  IconData _getIcon(String name) {
    return iconOptions[name] ?? Icons.local_cafe;
  }

  void _showAddHabitSheet() {
    final nameController = TextEditingController();
    String selectedIcon = 'local_cafe';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            return LiquidGlassContainer(
              borderRadius: 28,
              blurSigma: 30,
              opacity: 0.08,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Thêm thử thách mới',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),

                    // Habit name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Tên thói quen cần bỏ',
                        hintText: 'Ví dụ: Trà sữa, Cà phê, ...',
                        filled: true,
                        fillColor: theme.canvasColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(
                          _getIcon(selectedIcon),
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon picker
                    Text(
                      'Chọn biểu tượng',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconOptions.entries.map((entry) {
                        final isSelected = entry.key == selectedIcon;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => selectedIcon = entry.key);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primaryColor.withValues(alpha: 0.15)
                                  : theme.canvasColor,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              entry.value,
                              color: isSelected
                                  ? theme.primaryColor
                                  : theme.iconTheme.color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) return;
                          final box = Hive.box<HabitBreaker>('habitBreakers');
                          final habit = HabitBreaker(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            habitName: nameController.text.trim(),
                            iconName: selectedIcon,
                          );
                          box.add(habit);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Bắt đầu thử thách 🔥',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGameOver(HabitBreaker habit) {
    final streakLost = habit.currentStreak;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return _GameOverOverlay(
          streakLost: streakLost,
          habitName: habit.habitName,
          onRetry: () {
            habit.resetStreak();
            Navigator.pop(ctx);
          },
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

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
              onPressed: () {
                Navigator.pop(ctx);
                _showGameOver(habit);
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
                // Header
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
                            fontSize: 22,
                          ),
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
                  // Habit cards
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
                  // Bottom padding for dock
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
          onPressed: _showAddHabitSheet,
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
    final streakDays = habit.currentStreak;
    final bestStreak = habit.bestStreak;

    // Determine streak color intensity
    Color streakColor;
    if (streakDays >= 30) {
      streakColor = const Color(0xFFFFD700); // Gold
    } else if (streakDays >= 14) {
      streakColor = const Color(0xFFFF6B35); // Deep orange
    } else if (streakDays >= 7) {
      streakColor = const Color(0xFFFF9800); // Orange
    } else if (streakDays >= 3) {
      streakColor = const Color(0xFFFFC107); // Amber
    } else {
      streakColor = theme.primaryColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section: Icon, name, streak
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: streakColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIcon(habit.iconName),
                    color: streakColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Name + best streak
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
                        'Kỷ lục: $bestStreak ngày',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak counter
                Column(
                  children: [
                    Text(
                      '🔥',
                      style: TextStyle(fontSize: streakDays > 0 ? 28 : 20),
                    ),
                    Text(
                      '$streakDays',
                      style: TextStyle(
                        fontSize: 28,
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

          // Streak visual (last 7 days)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStreakCalendar(habit, theme, streakColor),
          ),

          // Badges
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

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Delete
                IconButton(
                  onPressed: () => _deleteHabit(habit),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.textTheme.bodyMedium?.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                // "I broke it" button
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

  Widget _buildStreakCalendar(
    HabitBreaker habit,
    ThemeData theme,
    Color streakColor,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final streakStart = DateTime(
      habit.startDate.year,
      habit.startDate.month,
      habit.startDate.day,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final isStreakDay = !day.isBefore(streakStart) && !day.isAfter(today);
        final isToday = day == today;
        final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        final dayName = dayNames[day.weekday - 1];

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
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isStreakDay
                    ? streakColor.withValues(alpha: 0.2)
                    : theme.canvasColor,
                shape: BoxShape.circle,
                border:
                    isToday ? Border.all(color: streakColor, width: 2) : null,
              ),
              child: Center(
                child: isStreakDay
                    ? Icon(Icons.check, color: streakColor, size: 18)
                    : Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────────
// Game Over Overlay
// ──────────────────────────────────────────────────
class _GameOverOverlay extends StatefulWidget {
  final int streakLost;
  final String habitName;
  final VoidCallback onRetry;

  const _GameOverOverlay({
    required this.streakLost,
    required this.habitName,
    required this.onRetry,
  });

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Start shake animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _shakeController.forward();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shake animation for GAME OVER text
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final shake = sin(_shakeController.value * pi * 4) *
                      8 *
                      (1 - _shakeController.value);
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: child,
                  );
                },
                child: const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                    shadows: [Shadow(color: Colors.redAccent, blurRadius: 20)],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Broken heart
              const Text('💔', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),

              // Stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Bạn đã mua ${widget.habitName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        children: [
                          const TextSpan(text: 'Chuỗi '),
                          TextSpan(
                            text: '${widget.streakLost} ngày',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.redAccent,
                            ),
                          ),
                          const TextSpan(text: ' đã bị mất 😢'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Motivational message
              const Text(
                'Không sao, thất bại là mẹ thành công!\nBắt đầu lại nào! 💪',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Retry button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 8,
                    shadowColor: Colors.redAccent.withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Thử lại 🔥',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
