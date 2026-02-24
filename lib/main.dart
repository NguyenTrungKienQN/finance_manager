import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/transaction_model.dart';
import 'models/settings_model.dart';
import 'models/savings_goal_model.dart';

import 'screens/savings_goals_screen.dart';
import 'screens/welcome_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';

import 'models/recurring_transaction_model.dart';
import 'services/notification_service.dart';
import 'widgets/privacy_wrapper.dart';
import 'widgets/liquid_glass.dart';
import 'screens/dashboard_screen.dart'; // For DashboardScreen usage in MyHomePage
import 'screens/recurring_screen.dart'; // Import RecurringScreen
import 'screens/debt_tracker_screen.dart'; // Import DebtTrackerScreen
import 'screens/habit_breaker_screen.dart'; // Import HabitBreakerScreen
import 'screens/ai_chat_screen.dart'; // Import AIChatScreen
import 'models/debt_record_model.dart'; // Import DebtRecord model
import 'models/habit_breaker_model.dart'; // Import HabitBreaker model
import 'theme/app_theme.dart'; // Correctly placed import

// Modern color palette
// AppColors class removed as we use AppTheme

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool hiveInitialized = false;
  String? initError;

  try {
    await Hive.initFlutter();
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(AppSettingsAdapter());
    Hive.registerAdapter(SavingsGoalAdapter());
    Hive.registerAdapter(RecurringTransactionAdapter());
    Hive.registerAdapter(RecurringFrequencyAdapter());
    Hive.registerAdapter(DebtRecordAdapter());
    Hive.registerAdapter(HabitBreakerAdapter());

    // Init Notifications and Open boxes in parallel
    await Future.wait([
      NotificationService().init(),
      Hive.openBox<Transaction>('transactions'),
      Hive.openBox<double>('budgetBox'),
      Hive.openBox<AppSettings>('settings'),
      Hive.openBox<SavingsGoal>('savingsGoals'),
      Hive.openBox<RecurringTransaction>('recurringTransactions'),
      Hive.openBox<DebtRecord>('debtRecords'),
      Hive.openBox<HabitBreaker>('habitBreakers'),
      Hive.openBox('currency_data'),
    ]);

    hiveInitialized = true;

    // Schedule daily morning notification (non-blocking, fire and forget)
    // We don't await this because the app can start while this schedules in background
    NotificationService().scheduleDailyMorningNotification();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print("Error initializing Hive: $e");
      print("Stack trace: $stackTrace");
    }
    initError = e.toString();
  }

  runApp(MyApp(hiveInitialized: hiveInitialized, initError: initError));
}

class MyApp extends StatelessWidget {
  final bool hiveInitialized;
  final String? initError;

  const MyApp({super.key, required this.hiveInitialized, this.initError});

  @override
  Widget build(BuildContext context) {
    if (!hiveInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: ErrorScreen(error: initError ?? 'Unknown error'),
      );
    }

    return ValueListenableBuilder<Box<AppSettings>>(
      valueListenable: Hive.box<AppSettings>('settings').listenable(),
      builder: (context, box, _) {
        final settings = box.get('appSettings') ?? AppSettings();
        final themeMode = settings.themeMode == 'dark'
            ? ThemeMode.dark
            : settings.themeMode == 'light'
                ? ThemeMode.light
                : ThemeMode.system;

        final isFirstInstall = box.get('appSettings') == null;

        return MaterialApp(
          title: 'Finance Manager',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('vi', 'VN')],
          themeMode: themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) {
            return PrivacyWrapper(child: child!);
          },
          home: isFirstInstall ? const WelcomeScreen() : const MyHomePage(),
        );
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.dangerGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lỗi khởi tạo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final List<int> _navHistory = [0];
  bool _isDockDragging = false; // Long-press drag mode
  late AnimationController _starBlinkController;
  late Animation<double> _starBlinkAnim;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SavingsGoalsScreen(),
    const RecurringScreen(),
    const DebtTrackerScreen(),
    const HabitBreakerScreen(),
    const AIChatScreen(),
  ];

  static const int _tabCount = 6;

  @override
  void initState() {
    super.initState();
    _starBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _starBlinkAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _starBlinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _starBlinkController.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (index == _currentIndex || index < 0 || index >= _tabCount) return;
    setState(() {
      _navHistory.add(index);
      _currentIndex = index;
    });
  }

  bool _onBack() {
    if (_navHistory.length > 1) {
      setState(() {
        _navHistory.removeLast();
        _currentIndex = _navHistory.last;
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Page content — instant switch, no animation
            IndexedStack(index: _currentIndex, children: _screens),

            // Floating Dock
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 100.0, end: 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Positioned(
                  left: 20,
                  right: 20,
                  bottom: 30 - value,
                  child: Opacity(
                    opacity: (1 - value / 100).clamp(0.0, 1.0),
                    child: child!,
                  ),
                );
              },
              child: LiquidGlassContainer(
                height: 70,
                borderRadius: 35,
                blurSigma: 25,
                opacity: 0.08,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / _tabCount;
                    return GestureDetector(
                      // Long press + drag to swipe between tabs
                      onHorizontalDragStart: (details) {
                        final idx = (details.localPosition.dx / itemWidth)
                            .floor()
                            .clamp(0, _tabCount - 1);
                        setState(() {
                          _isDockDragging = true;
                        });
                        _navigateTo(idx);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (!_isDockDragging) return;
                        final idx = (details.localPosition.dx / itemWidth)
                            .floor()
                            .clamp(0, _tabCount - 1);
                        if (idx != _currentIndex) {
                          _navigateTo(idx);
                        }
                      },
                      onHorizontalDragEnd: (_) {
                        _isDockDragging = false;
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Sliding pill indicator with spring animation
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutBack,
                            left: _currentIndex * itemWidth + 8,
                            top: 8,
                            bottom: 8,
                            width: itemWidth - 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Tab items
                          Row(
                            children: [
                              _buildDockItem(
                                0,
                                Icons.home_rounded,
                                'Trang chủ',
                                itemWidth,
                              ),
                              _buildDockItem(
                                1,
                                Icons.savings_rounded,
                                'Hũ',
                                itemWidth,
                              ),
                              _buildDockItem(
                                2,
                                Icons.calendar_today_rounded,
                                'Định kỳ',
                                itemWidth,
                              ),
                              _buildDockItem(
                                3,
                                Icons.receipt_long_rounded,
                                'Sổ nợ',
                                itemWidth,
                              ),
                              _buildDockItem(
                                4,
                                Icons.local_fire_department_rounded,
                                'Thử thách',
                                itemWidth,
                              ),
                              _buildDockItem(
                                5,
                                Icons.auto_awesome,
                                'AI Chat',
                                itemWidth,
                                blinkAnimation: _starBlinkAnim,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockItem(
    int index,
    IconData icon,
    String label,
    double width, {
    Animation<double>? blinkAnimation,
  }) {
    final bool isSelected = _currentIndex == index;
    // final bool isPopped = _isDockDragging && _pressedIndex == index; // Removed popup effect

    Widget iconWidget = Icon(
      icon,
      color: isSelected
          ? Theme.of(context).primaryColor
          : Theme.of(context).textTheme.bodyMedium?.color,
      size: 24,
    );

    // Apply blinking animation if provided and not selected
    if (blinkAnimation != null && !isSelected) {
      iconWidget = AnimatedBuilder(
        animation: blinkAnimation,
        builder: (context, child) {
          return Opacity(opacity: blinkAnimation.value, child: child);
        },
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: () => _navigateTo(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 70,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: isSelected ? 1.1 : 1.0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: iconWidget,
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
