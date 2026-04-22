import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/weekly_chart_widget.dart';
import '../widgets/dashboard_stack.dart';
import '../theme/app_theme.dart';
import '../models/habit_breaker_model.dart';
import '../widgets/home_widgets/modern_home_widgets.dart';
import '../widgets/habit_broken_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_time_service.dart';
import '../services/category_registry.dart';
import '../services/gemini_chat_service.dart';
import '../services/notification_service.dart';
import '../utils/habit_helper.dart';
import '../main.dart';
import '../utils/app_toast.dart';
import '../models/spending_category_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late double _dailyLimit;      // Rollover-adjusted, used for AddTransaction & home widget
  late double _baseDailyLimit;   // Raw monthlySalary / daysInMonth, used for cards that self-compute rollover
  late double _monthlySalary;
  DateTime _selectedDate = AppTimeService.instance.now();
  String _userName = "Bạn";
  String? _headerBackgroundImagePath;
  Color? _headerContentColor;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  String? _selectedCategoryFilter; // null = "Tất cả"

  Future<void> _handleMatchedHabitRelapse(HabitBreaker habit) async {
    final lostStreak = habit.currentStreak;
    final result = habit.handleRelapse();

    if (result == RelapseResult.fullReset) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_broken_habit_id', habit.id);
      await prefs.setString(
        'last_broken_time',
        AppTimeService.instance.now().toIso8601String(),
      );
    }

    if (!mounted) {
      _updateHomeWidget();
      return;
    }

    if (result == RelapseResult.shieldAbsorbed) {
      await showShieldAbsorbedDialog(context, habitName: habit.habitName);
    } else if (result == RelapseResult.frozen) {
      await NotificationService().fireStreakFrozen(habit);
      if (!mounted) return;
      await showStreakFrozenDialog(context, habitName: habit.habitName);
    } else {
      await showFullResetDialog(
        context,
        habitName: habit.habitName,
        lostStreak: lostStreak,
      );
    }

    _updateHomeWidget();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
    HomeWidget.setAppGroupId('group.com.therize.fmanager');
    AppTimeService.instance.overrideNotifier.addListener(_handleTimeOverride);
    _loadSettings();
    Hive.box<Transaction>(
      'transactions',
    ).listenable().addListener(_updateHomeWidget);
    Hive.box<HabitBreaker>(
      'habitBreakers',
    ).listenable().addListener(_updateHomeWidget);
    Hive.box<Transaction>(
      'transactions',
    ).listenable().addListener(_checkBudgetVelocities);

    _checkForWidgetLaunch();
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri == null || uri.scheme != 'fmanager') return;

    final target = uri.host;

    if (target == 'add_transaction' || uri.path.contains('add_transaction')) {
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddTransactionScreen(dailyLimit: _dailyLimit),
            ),
          );

          if (result != null && result is HabitBreaker) {
            await _handleMatchedHabitRelapse(result);
          } else {
            _updateHomeWidget();
          }
        }
      });
    } else if (target == 'habit_breaker' ||
        uri.path.contains('habit_breaker')) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Navigate to Habit Breaker tab (index 4) using the GlobalKey
          MyHomePage.globalKey.currentState?.navigateToTab(4);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    AppTimeService.instance.overrideNotifier
        .removeListener(_handleTimeOverride);
    Hive.box<Transaction>(
      'transactions',
    ).listenable().removeListener(_updateHomeWidget);
    Hive.box<HabitBreaker>(
      'habitBreakers',
    ).listenable().removeListener(_updateHomeWidget);
    super.dispose();
  }

  void _handleTimeOverride() {
    if (!mounted) return;
    setState(() {
      _selectedDate = AppTimeService.instance.now();
    });
    _loadSettings();
  }

  void _loadSettings() {
    final settingsBox = Hive.box<AppSettings>('settings');
    AppSettings? settings = settingsBox.get('appSettings');
    if (settings == null) {
      settings = AppSettings();
      settingsBox.put('appSettings', settings);
    }
    setState(() {
      _monthlySalary = settings!.monthlySalary;
      _dailyLimit = settings.computedDailyLimit;
      // Base limit should be universally consistent with SettingsModel logic,
      // correctly accounting for monthly fixed categories and tracking dates.
      final now = AppTimeService.instance.now();
      _baseDailyLimit = settings.baseDailyLimitFor(now);
      
      _userName = settings.userName;
      _headerBackgroundImagePath = settings.headerBackgroundImagePath;
    });
    _updateHeaderColor();
    _updateHomeWidget();
    _checkBudgetVelocities();
  }

  Future<void> _updateHeaderColor() async {
    if (_headerBackgroundImagePath == null) {
      if (mounted) {
        setState(() {
          _headerContentColor = null;
        });
      }
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(File(_headerBackgroundImagePath!)),
        maximumColorCount: 10,
      );

      if (mounted) {
        // We look at the dominant color or targeted area
        final dominant = palette.dominantColor?.color ?? Colors.black;
        // If it's bright (> 0.5), use black text. Otherwise white.
        setState(() {
          _headerContentColor =
              dominant.computeLuminance() > 0.5 ? Colors.black : Colors.white;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error generating palette: $e");
    }
  }

  void _updateHomeWidget() async {
    if (kIsWeb) return; // Prevent Home Widget code from executing on web

    // Helper to get exact widget size requested by Android
    Future<Size> getWidgetLogicalSize(String key, Size defaultSize) async {
      try {
        final width = await HomeWidget.getWidgetData<int>('${key}_width');
        final height = await HomeWidget.getWidgetData<int>('${key}_height');
        if (width != null && height != null && width > 0 && height > 0) {
          // Add 10% padding buffer since dp conversion isn't always exact pixel perfect on Android
          return Size(width.toDouble() * 1.1, height.toDouble() * 1.1);
        }
      } catch (e) {
        if (kDebugMode) print("Error reading widget size for \$key: \$e");
      }
      return defaultSize;
    }

    try {
      final now = AppTimeService.instance.now();
      final box = Hive.box<Transaction>('transactions');
      final allTransactions = box.values.toList();

      // === Daily Balance Data ===
      double todaySpent = allTransactions
          .where(
            (t) =>
                t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day,
          )
          .fold(0.0, (sum, t) => sum + t.amount);

      try {
        await HomeWidget.renderFlutterWidget(
          DailyBalanceHomeWidget(spent: todaySpent, limit: _dailyLimit),
          logicalSize: await getWidgetLogicalSize(
              'widget_daily_balance', const Size(360, 170)),
          key: 'widget_daily_balance_image',
        );
        await HomeWidget.saveWidgetData<String>(
            'todaySpent', todaySpent.toString());
        await HomeWidget.saveWidgetData<String>(
            'dailyLimit', _dailyLimit.toString());
      } catch (e) {
        if (kDebugMode) print("Error rendering daily balance widget: $e");
      }

      // === Forecast Data ===
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      final monthlyTransactions = allTransactions
          .where((t) => t.date.year == now.year && t.date.month == now.month)
          .toList();
      double monthlySpent = monthlyTransactions.fold(
        0.0,
        (sum, t) => sum + t.amount,
      );
      double avgDailySpend = now.day > 0 ? monthlySpent / now.day : 0;
      int daysRemaining = daysInMonth - now.day;
      double projectedTotal = monthlySpent + (avgDailySpend * daysRemaining);
      double monthlyBudget = _monthlySalary;

      try {
        await HomeWidget.renderFlutterWidget(
          ForecastHomeWidget(
            projectedTotal: projectedTotal,
            monthlyBudget: monthlyBudget,
            avgDailySpend: avgDailySpend,
          ),
          logicalSize: await getWidgetLogicalSize(
              'widget_forecast', const Size(360, 170)),
          key: 'widget_forecast_image',
        );
        await HomeWidget.saveWidgetData<String>(
            'projectedSpend', projectedTotal.toString());
        await HomeWidget.saveWidgetData<String>(
            'monthlyBudget', monthlyBudget.toString());
        await HomeWidget.saveWidgetData<String>(
            'avgDailySpend', avgDailySpend.toString());
      } catch (_) {}

      // === Habit Breaker Data ===
      try {
        final habitBox = Hive.box<HabitBreaker>('habitBreakers');
        final activeHabits = habitBox.values.where((h) => h.isActive).toList();

        String habitName = "Chưa có thử thách";
        int streak = 0;
        String status = "Tạo thử thách để bắt đầu";
        String habitWidgetState = "none";

        if (activeHabits.isNotEmpty) {
          for (final habit in activeHabits) {
            habit.ensureBackwardCompatibility();
            habit.advanceStreak();
          }

          activeHabits.sort(
            (a, b) => b.currentStreak.compareTo(a.currentStreak),
          );
          final topHabit = activeHabits.first;
          habitName = topHabit.habitName;
          streak = topHabit.currentStreak;
          habitWidgetState = topHabit.getWidgetState();
          status = topHabit.getStatusText();
        }

        await HomeWidget.renderFlutterWidget(
          HabitBreakerHomeWidget(
            habitName: habitName,
            streak: streak,
            status: status,
          ),
          logicalSize: await getWidgetLogicalSize(
            'widget_habit_breaker',
            const Size(340, 170),
          ),
          key: 'widget_habit_breaker_image',
        );
        await HomeWidget.saveWidgetData<String>('habitName', habitName);
        await HomeWidget.saveWidgetData<String>(
            'habitStreak', streak.toString());
        await HomeWidget.saveWidgetData<String>('habitStatus', status);
        await HomeWidget.saveWidgetData<String>(
            'habitWidgetState', habitWidgetState);
      } catch (e) {
        if (kDebugMode) print("Error updating habit widget: $e");
      }

      // === Quick Add Data ===
      final todayTransactions = allTransactions.where(
        (t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day,
      );
      try {
        await HomeWidget.renderFlutterWidget(
          QuickAddHomeWidget(
              todaySpent: todaySpent, txCount: todayTransactions.length),
          logicalSize: await getWidgetLogicalSize(
              'widget_quick_add', const Size(170, 170)),
          key: 'widget_quick_add_image',
        );
        await HomeWidget.saveWidgetData<String>(
            'quickAddTodaySpent', todaySpent.toString());
        await HomeWidget.saveWidgetData<String>(
            'quickAddTxCount', todayTransactions.length.toString());
      } catch (_) {}

      // Update all widgets
      await HomeWidget.updateWidget(
          name: 'DailyBalanceWidgetReceiver',
          qualifiedAndroidName:
              'com.therize.fmanager.glance.DailyBalanceWidgetReceiver',
          iOSName: 'DailyBalanceWidget');
      await HomeWidget.updateWidget(
          name: 'ForecastWidgetReceiver',
          qualifiedAndroidName:
              'com.therize.fmanager.glance.ForecastWidgetReceiver',
          iOSName: 'ForecastWidget');
      await HomeWidget.updateWidget(
          name: 'QuickAddWidgetReceiver',
          qualifiedAndroidName:
              'com.therize.fmanager.glance.QuickAddWidgetReceiver',
          iOSName: 'QuickAddWidget');
      await HomeWidget.updateWidget(
          name: 'HabitBreakerWidgetReceiver',
          qualifiedAndroidName:
              'com.therize.fmanager.glance.HabitBreakerWidgetReceiver',
          iOSName: 'HabitBreakerWidget');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating home widget: $e');
      }
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  bool get _isToday {
    final now = AppTimeService.instance.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _checkBudgetVelocities() async {
    final box = Hive.box<Transaction>('transactions');
    final now = AppTimeService.instance.now();
    final categories = CategoryRegistry.instance.getAll();

    for (final cat in categories) {
      if (cat.budget == null || cat.budget! <= 0) continue;

      double monthSpent = 0;
      final Map<int, double> dailySpending = {};

      for (final t in box.values) {
        if (t.date.year == now.year && t.date.month == now.month) {
          if (t.category == cat.name) {
            monthSpent += t.amount;
            dailySpending[t.date.day] = (dailySpending[t.date.day] ?? 0) + t.amount;
          }
        }
      }

      final int currentDay = now.day;
      final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final int daysWithData = dailySpending.keys.length;

      // Only forecast if not already over budget
      final bool isMonthly = cat.budgetPeriod == BudgetPeriod.monthly;
      final double effectiveMonthlyBudget = isMonthly ? cat.budget! : cat.budget! * daysInMonth;
      final double ratio = monthSpent / effectiveMonthlyBudget;

      // Always check for threshold alerts (50%, 80%, 100%)
      if (ratio >= 0.5) {
        NotificationService().fireCategoryThresholdAlert(
          category: cat.name,
          ratio: ratio,
        );
      }
      
      if (daysWithData >= 3 && monthSpent < effectiveMonthlyBudget) {
        final double mtdAverage = monthSpent / currentDay;
        final int recentWindow = currentDay < 7 ? currentDay : 7;
        double recentSum = 0;
        for (int d = currentDay; d > currentDay - recentWindow; d--) {
          recentSum += dailySpending[d] ?? 0;
        }
        final double recentAverage = recentSum / recentWindow;
        final double velocity = (recentAverage * 0.7) + (mtdAverage * 0.3);

        if (velocity > 0) {
          final double remainingBudget = effectiveMonthlyBudget - monthSpent;
          final int daysUntilExhausted = (remainingBudget / velocity).floor();
          final exhaustionDate = now.add(Duration(days: daysUntilExhausted));
          final lastDayOfMonth = DateTime(now.year, now.month, daysInMonth);

          if (exhaustionDate.isBefore(lastDayOfMonth)) {
            final daysEarly = lastDayOfMonth.difference(exhaustionDate).inDays;
            
            // Fire proactive warning if at least 3 days early
            if (daysEarly >= 3) {
              NotificationService().fireVelocityWarning(
                category: cat.name,
                daysEarly: daysEarly,
                exhaustionDate: exhaustionDate,
              );
            }
          }
        }
      }
    }

    // Tự động gợi ý thói quen In-app
    final habitSuggestion = GeminiChatService().fastCheckHabits();
    if (habitSuggestion != null && mounted) {
      final String habitName = habitSuggestion['habit_name'] ?? '';
      debugPrint('[AI Auto Suggest] Kiểm tra thói quen: $habitName');
      
      // Kiểm tra có đang tham gia thử thách này không
      final activeHabits = Hive.box<HabitBreaker>('habitBreakers').values.toList();
      final alreadyTracking = activeHabits.any((h) => 
          h.habitName.toLowerCase() == habitName.toLowerCase() && h.isActive);
      
      if (alreadyTracking) {
        debugPrint('[AI Auto Suggest] Bỏ qua vì đã có thử thách đang chạy cho $habitName');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final nowStr = now.toIso8601String().split('T')[0];
      
      // Không spam, chỉ hỏi 1 lần/ngày/thói quen
      final lastPrompt = prefs.getString('last_inapp_habit_prompt_$habitName');
      if (lastPrompt == nowStr) {
        debugPrint('[AI Auto Suggest] Bỏ qua vì hôm nay ($nowStr) đã nhắc thói quen $habitName rồi');
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        
        // Kiểm tra lại lần nữa trong callback để chắc chắn không hiện đè
        await prefs.setString('last_inapp_habit_prompt_$habitName', nowStr);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('AI Phát hiện thói quen', style: Theme.of(ctx).textTheme.titleLarge)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gợi ý: Bắt đầu bỏ $habitName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    habitSuggestion['reason'] ?? 'Bạn đang chi tiêu khá nhiều cho khoản này. Hãy thử thách bản thân để tiết kiệm hơn!',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Để sau', style: TextStyle(color: Theme.of(ctx).textTheme.bodySmall?.color)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    HabitHelper.showAddHabitSheet(context, initialName: habitName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Xem ngay'),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  void _showSettingsDialog() async {
    final result = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentSalary: _monthlySalary),
      ),
    );
    _selectedDate = AppTimeService.instance.now();
    _loadSettings();
    if (result != null) {
      NotificationService().scheduleAllSmartNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by AppTheme or Main
      body: Stack(
        children: [
          // Dynamic Header Background with Parallax
          ValueListenableBuilder<double>(
            valueListenable: _scrollOffset,
            builder: (context, offset, _) {
              return _DashboardHeaderBackground(
                imagePath: _headerBackgroundImagePath,
                scrollOffset: offset,
              );
            },
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 1. Soft Header ---
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 20,
                  24,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Avatar / Profile Pic
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppTheme.softPurple.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào,',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _headerContentColor ??
                                      Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                ),
                              ),
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _headerContentColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Date & Settings Controls
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeDate(-1),
                            icon: const Icon(Icons.chevron_left, size: 28),
                            color: _headerContentColor ??
                                Theme.of(context).iconTheme.color,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('d').format(_selectedDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      height: 1.0,
                                      color: _headerContentColor,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM').format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.0,
                                      color: _headerContentColor ??
                                          Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_isToday)
                            IconButton(
                              onPressed: () => _changeDate(1),
                              icon: const Icon(Icons.chevron_right, size: 28),
                              color: _headerContentColor ??
                                  Theme.of(context).iconTheme.color,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _showSettingsDialog,
                            icon: const Icon(Icons.settings_outlined),
                            color: _headerContentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- 2. Spacer (ONLY when background image exists) ---
              if (_headerBackgroundImagePath != null)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280.0 -
                        MediaQuery.of(context).padding.top -
                        80, // 80 is approx greeting height
                  ),
                ),

              // --- 3. Dashboard Cards ---
              SliverToBoxAdapter(
                child: DashboardStack(
                  dailyLimit: _baseDailyLimit,
                  monthlySalary: _monthlySalary,
                  selectedDate: _selectedDate,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // --- 3. Weekly Chart ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(32), // Soft rounded
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng quan tuần',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: WeeklyChartWidget(
                            dailyLimit: _baseDailyLimit,
                            selectedDate: _selectedDate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // --- 4. Transactions List ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao dịch gần đây',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      // Magic Clean Button
                      ValueListenableBuilder(
                        valueListenable:
                            Hive.box<Transaction>('transactions').listenable(),
                        builder: (context, box, _) {
                          final messyCount = box.values
                              .where((t) => t.category == 'Khác')
                              .length;
                          if (messyCount == 0) return const SizedBox.shrink();

                          return ActionChip(
                            avatar: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 16),
                            label: Text('Dọn $messyCount mục',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.purple,
                            side: BorderSide.none,
                            onPressed: () => _showMagicCleanSheet(context),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // --- 4b. Category Filter Chips ---
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildCategoryChip(null, 'Tất cả'),
                      ...CategoryRegistry.instance.getAll().map(
                        (cat) => _buildCategoryChip(cat.name, cat.name),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // --- 4c. Category Stats Card (when a specific category is selected) ---
              if (_selectedCategoryFilter != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCategoryStatsCard(),
                  ),
                ),

              if (_selectedCategoryFilter != null)
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // --- 4d. Filtered Transaction List ---
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: ValueListenableBuilder(
                  valueListenable: Hive.box<Transaction>(
                    'transactions',
                  ).listenable(),
                  builder: (context, box, _) {
                    var dayTransactions = box.values
                        .where(
                          (t) =>
                              t.date.year == _selectedDate.year &&
                              t.date.month == _selectedDate.month &&
                              t.date.day == _selectedDate.day,
                        )
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    // Apply category filter
                    if (_selectedCategoryFilter != null) {
                      dayTransactions = dayTransactions
                          .where((t) => t.category == _selectedCategoryFilter)
                          .toList();
                    }

                    if (dayTransactions.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    size: 40,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedCategoryFilter != null
                                      ? "Không có giao dịch $_selectedCategoryFilter"
                                      : "Chưa có giao dịch",
                                  style: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTransactionItem(dayTransactions[index]),
                        );
                      }, childCount: dayTransactions.length),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ), // Space for dock
            ],
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100), // Lift above Floating Dock
        child: FloatingActionButton.extended(
          heroTag: 'fab_dashboard',
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(dailyLimit: _dailyLimit),
              ),
            );
            if (result != null && result is HabitBreaker) {
              await _handleMatchedHabitRelapse(result);
            } else {
              _updateHomeWidget();
            }
          },
          backgroundColor: AppTheme.softPurple,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.expressiveRadius),
          ),
          label: const Text(
            "Thêm mới",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        transaction.delete();
        _updateHomeWidget(); // Update widgets after deletion
        NotificationService().scheduleAllSmartNotifications();
        AppToast.show(context, 'Đã xóa giao dịch');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getCategoryColor(
                transaction.category,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: _getCategoryColor(transaction.category),
              size: 24,
            ),
          ),
          title: Text(
            transaction.category,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: transaction.notes != null && transaction.notes!.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    transaction.notes!,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(
                  locale: 'vi',
                  symbol: '₫',
                  decimalDigits: 0,
                ).format(transaction.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.redAccent,
                ),
              ),
              if (transaction.isOverBudget)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Vượt hạn mức',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            // Details or Edit handling
          },
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    return CategoryRegistry.instance.getColor(category);
  }

  IconData _getCategoryIcon(String category) {
    return CategoryRegistry.instance.getIcon(category);
  }

  Widget _buildCategoryChip(String? categoryName, String label) {
    final isSelected = _selectedCategoryFilter == categoryName;
    final color = categoryName != null
        ? CategoryRegistry.instance.getColor(categoryName)
        : Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryFilter = categoryName;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (categoryName != null) ...[
                Icon(
                  CategoryRegistry.instance.getIcon(categoryName),
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStatsCard() {
    final category = _selectedCategoryFilter!;
    final catColor = CategoryRegistry.instance.getColor(category);
    final catIcon = CategoryRegistry.instance.getIcon(category);
    final budget = CategoryRegistry.instance.getBudget(category);
    final period = CategoryRegistry.instance.getBudgetPeriod(category);
    final fmt = NumberFormat('#,###', 'vi_VN');

    final box = Hive.box<Transaction>('transactions');
    final now = _selectedDate;

    // Calculate spent for this category today
    double todaySpent = 0;
    double monthSpent = 0;
    double totalMonthSpent = 0;
    final Map<int, double> dailySpending = {}; // day -> amount for this category

    for (final t in box.values) {
      if (t.date.year == now.year && t.date.month == now.month) {
        totalMonthSpent += t.amount;
        if (t.category == category) {
          monthSpent += t.amount;
          dailySpending[t.date.day] = (dailySpending[t.date.day] ?? 0) + t.amount;
          if (t.date.day == now.day) {
            todaySpent += t.amount;
          }
        }
      }
    }

    // Determine which spent amount & label to display based on budget period
    final bool isMonthly = period == BudgetPeriod.monthly;
    final double displaySpent = (budget != null && isMonthly) ? monthSpent : todaySpent;
    final String periodLabel = (budget != null && isMonthly) ? 'tháng này' : 'hôm nay';

    // Share percentage calculation
    final double sharePercent = totalMonthSpent > 0 ? (monthSpent / totalMonthSpent) * 100 : 0.0;
    final String shareStr = sharePercent == sharePercent.roundToDouble() 
        ? '${sharePercent.toInt()}%' 
        : '${sharePercent.toStringAsFixed(1)}%';
    final bool isDominant = sharePercent >= 40;

    // Budget progress and utility flags (Moved up for forecasting logic)
    final bool hasBudget = budget != null && budget > 0;
    final double displaySpentForProgress = (budget != null && isMonthly) ? monthSpent : todaySpent;
    final double progress = hasBudget ? (displaySpentForProgress / budget).clamp(0.0, 1.0) : 0;
    final bool isOver = hasBudget && displaySpentForProgress > budget;

    // --- Budget Velocity Forecasting ---
    final int currentDay = now.day;
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int daysWithData = dailySpending.keys.length;

    DateTime? exhaustionDate;
    bool isSustainable = true;
    int? daysEarly;

    if (hasBudget && daysWithData >= 3 && !isOver) {
      // Linear month-to-date average
      final double mtdAverage = monthSpent / currentDay;

      // Last 7 days average (recency weighting)
      final int recentWindow = currentDay < 7 ? currentDay : 7;
      double recentSum = 0;
      for (int d = currentDay; d > currentDay - recentWindow; d--) {
        recentSum += dailySpending[d] ?? 0;
      }
      final double recentAverage = recentSum / recentWindow;

      // Weighted velocity: 70% recent, 30% month-to-date
      final double velocity = (recentAverage * 0.7) + (mtdAverage * 0.3);

      if (velocity > 0) {
        // Normalize budget to monthly equivalent if it's a daily limit
        final double effectiveMonthlyBudget = isMonthly ? budget : budget * daysInMonth;
        final double remainingBudget = effectiveMonthlyBudget - monthSpent;

        if (remainingBudget > 0) {
          final int daysUntilExhausted = (remainingBudget / velocity).floor();
          exhaustionDate = now.add(Duration(days: daysUntilExhausted));
          
          final lastDayOfMonth = DateTime(now.year, now.month, daysInMonth);
          isSustainable = !exhaustionDate.isBefore(lastDayOfMonth);
          
          if (!isSustainable) {
            daysEarly = lastDayOfMonth.difference(exhaustionDate).inDays;
          }
        } else {
          isSustainable = false;
        }
      }
    }

    // Color gradient based on progress
    Color progressColor;
    if (!hasBudget) {
      progressColor = catColor;
    } else if (progress < 0.6) {
      progressColor = const Color(0xFF4CAF50); // Green
    } else if (progress < 0.85) {
      progressColor = const Color(0xFFFF9800); // Orange
    } else {
      progressColor = const Color(0xFFEF5350); // Red
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Icon + Name + Amount
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(catIcon, color: catColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chi tiêu $periodLabel',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(displaySpent.toInt())}\u20ab',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isOver ? Colors.redAccent : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (hasBudget)
                    Text(
                      '/ ${fmt.format(budget.toInt())}\u20ab',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Budget progress bar (only if budget is set)
          if (hasBudget) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: progressColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isOver)
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Vu\u01b0\u1ee3t h\u1ea1n m\u1ee9c',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'C\u00f2n l\u1ea1i: ${fmt.format((budget - displaySpent).toInt())}\u20ab',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],

          // Monthly total shown as secondary info when viewing daily
          if (hasBudget && !isMonthly) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 14, color: catColor),
                  const SizedBox(width: 8),
                  Text(
                    'Tổng tháng: ${fmt.format(monthSpent.toInt())}\u20ab',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Monthly Share Indicator (ALWAYS shown)
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isDominant ? Icons.warning_amber_rounded : Icons.pie_chart_outline_rounded,
                  size: 14,
                  color: isDominant ? Colors.orange : catColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chiếm $shareStr tổng chi tháng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isDominant ? FontWeight.bold : FontWeight.w600,
                    color: isDominant
                        ? Colors.orange
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Budget Velocity Forecast (Proactive Indicator)
          if (hasBudget && daysWithData >= 3 && !isOver) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isSustainable ? const Color(0xFF4CAF50) : Colors.redAccent).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isSustainable ? const Color(0xFF4CAF50) : Colors.redAccent).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSustainable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 14,
                    color: isSustainable ? const Color(0xFF4CAF50) : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSustainable 
                        ? 'Tốc độ chi tiêu hợp lý ✓'
                        : 'Dự kiến hết ngân sách: ${DateFormat('dd/MM').format(exhaustionDate ?? now)} ${daysEarly != null ? "($daysEarly ngày sớm)" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSustainable ? const Color(0xFF4CAF50) : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showMagicCleanSheet(BuildContext context) async {
    final box = Hive.box<Transaction>('transactions');
    final messyTxs = box.values.where((t) => t.category == 'Khác').toList();
    if (messyTxs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MagicCleanSheet(messyTxs: messyTxs, txBox: box),
    );
  }
}

class _MagicCleanSheet extends StatefulWidget {
  final List<Transaction> messyTxs;
  final Box<Transaction> txBox;

  const _MagicCleanSheet({required this.messyTxs, required this.txBox});

  @override
  State<_MagicCleanSheet> createState() => _MagicCleanSheetState();
}

class _MagicCleanSheetState extends State<_MagicCleanSheet> {
  bool _isLoading = true;
  Map<String, String>? _suggestions;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  void _fetchSuggestions() async {
    final ai = GeminiChatService();
    final results = await ai.batchCategorizeTransactions(widget.messyTxs);
    if (mounted) {
      setState(() {
        _suggestions = results;
        // Filter out items that AI still thinks are 'Khác'
        if (_suggestions != null) {
          _suggestions!.removeWhere((k, v) => v == 'Khác');
        }
        _isLoading = false;
      });
    }
  }

  void _applyAll() {
    if (_suggestions == null || _suggestions!.isEmpty) return;

    for (var tx in widget.messyTxs) {
      if (_suggestions!.containsKey(tx.id)) {
        final newTx = Transaction(
          id: tx.id,
          amount: tx.amount,
          category: _suggestions![tx.id]!,
          date: tx.date,
          isOverBudget: tx.isOverBudget,
          notes: tx.notes,
          unitPrice: tx.unitPrice,
          quantity: tx.quantity,
        );
        widget.txBox.put(tx.key, newTx);
      }
    }

    Navigator.pop(context);
    AppToast.show(context, '✨ Đã dọn dẹp danh mục thành công!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text('Magic Clean',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'AI đang hỗ trợ chuyển đổi các giao dịch "Khác" về đúng danh mục.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: Colors.purple),
            )
          else if (_suggestions == null || _suggestions!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Text('Không tìm thấy gợi ý nào mới.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.messyTxs.length,
                itemBuilder: (context, index) {
                  final tx = widget.messyTxs[index];
                  final newCat = _suggestions![tx.id];
                  if (newCat == null) return const SizedBox.shrink();

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx.notes ?? 'Không có ghi chú',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${NumberFormat.currency(locale: 'vi', symbol: '₫', decimalDigits: 0).format(tx.amount)} - ${DateFormat('dd/MM/yyyy').format(tx.date)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Khác',
                            style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(newCat,
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_isLoading || _suggestions == null || _suggestions!.isEmpty)
                      ? null
                      : _applyAll,
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: const Text('Duyệt tất cả',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DashboardHeaderBackground extends StatelessWidget {
  final String? imagePath;
  final double scrollOffset;

  const _DashboardHeaderBackground({
    this.imagePath,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Fixed Hero Height for consistent MB Bank-like look
    final heroHeight = 280.0;

    // Parallax effect: moves up at 40% speed
    final parallaxTop = -scrollOffset * 0.4;

    return Positioned(
      top: parallaxTop,
      left: 0,
      right: 0,
      height: heroHeight,
      child: Stack(
        children: [
          // Base Background (Fallback)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primaryColor.withValues(alpha: 0.1),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),

          // Custom Image
          if (imagePath != null)
            Positioned.fill(
              child: ClipRRect(
                child: Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          // Overlay for contrast & transition
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25), // Dim top slightly
                    Colors.black.withValues(alpha: 0.05),
                    theme.scaffoldBackgroundColor, // Fade to scaffold color
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
