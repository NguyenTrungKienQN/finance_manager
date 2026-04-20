import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/settings_model.dart';
import 'daily_balance_card.dart';
import 'weekly_summary_card.dart';
import 'spending_forecast_card.dart';
import 'savings_overview_card.dart';
import 'monthly_summary_card.dart';
import 'safe_balance_card.dart';
import 'currency_converter_sheet.dart';

class DashboardStack extends StatefulWidget {
  final double dailyLimit;
  final double monthlySalary;
  final DateTime selectedDate;

  const DashboardStack({
    super.key,
    required this.dailyLimit,
    required this.monthlySalary,
    required this.selectedDate,
  });

  static void showDepositDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nạp tiền vào Két sắt',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tiết kiệm chỉ có ý nghĩa khi nó mang tính chủ động.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Số tiền nạp',
                  hintText: '0',
                  suffixText: 'đ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.currency_exchange),
                    onPressed: () => CurrencyConverterSheet.show(ctx, targetController: controller),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text.replaceAll(RegExp(r'[,.]'), '')) ?? 0;
                    if (val > 0) {
                      final box = Hive.box<AppSettings>('settings');
                      final settings = box.get('appSettings') ?? AppSettings();
                      settings.safeBalance += val;
                      settings.save();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã nạp ${NumberFormat.simpleCurrency(locale: "vi_VN", decimalDigits: 0).format(val)} vào Két sắt')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Xác nhận nạp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<DashboardStack> createState() => _DashboardStackState();
}

class _DashboardStackState extends State<DashboardStack> {
  bool _showOtterCard = false;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkOtterIntro();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkOtterIntro() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();
    if (!settings.hasSeenOtterIntro && !settings.isFirstInstall) {
      _showOtterCard = true;
    }
  }

  void _dismissOtterCard() {
    final settingsBox = Hive.box<AppSettings>('settings');
    final settings = settingsBox.get('appSettings') ?? AppSettings();
    if (!settings.hasSeenOtterIntro) {
      settings.hasSeenOtterIntro = true;
      settings.save();
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const double cardHeight = 240.0;

    final List<Widget> cards = [];

    if (_showOtterCard) {
      cards.add(
        GestureDetector(
          onTap: _dismissOtterCard,
          child: const _OtterWelcomeCard(),
        ),
      );
    }

    cards.addAll([
      GestureDetector(
        onTap: () => _showExpandedCards(context),
        child: DailyBalanceCard(
            dailyLimit: widget.dailyLimit, selectedDate: widget.selectedDate),
      ),
      SafeBalanceCard(
        onDeposit: () => DashboardStack.showDepositDialog(context),
      ),
      GestureDetector(
        onTap: () => _showExpandedCards(context),
        child: WeeklySummaryCard(selectedDate: widget.selectedDate),
      ),
      GestureDetector(
        onTap: () => _showExpandedCards(context),
        child: SpendingForecastCard(
          dailyLimit: widget.dailyLimit,
          monthlySalary: widget.monthlySalary,
        ),
      ),
      GestureDetector(
        onTap: () => _showExpandedCards(context),
        child: const SavingsOverviewCard(),
      ),
      GestureDetector(
        onTap: () => _showExpandedCards(context),
        child: MonthlySummaryCard(
          dailyLimit: widget.dailyLimit,
          monthlySalary: widget.monthlySalary,
        ),
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: cardHeight,
        child: Stack(
          children: [
            // The actual vertical PageView — iOS Smart Stack style
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: cards.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return cards[index];
                },
              ),
            ),

            // Right-side dot indicator (like iOS Smart Stack)
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(cards.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    width: isActive ? 7 : 5,
                    height: isActive ? 7 : 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpandedCards(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _ExpandedCardsOverlay(
          dailyLimit: widget.dailyLimit,
          monthlySalary: widget.monthlySalary,
          selectedDate: widget.selectedDate,
          animation: anim1,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) => child,
    );
  }
}

// ============================================================
// OTTER WELCOME CARD
// ============================================================
class _OtterWelcomeCard extends StatelessWidget {
  const _OtterWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF764BA2).withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient glow orb
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Content row
          Row(
            children: [
              // Mascot on the left
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Image.asset(
                  'assets/mascots/mascotfirst.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              // Text content on the right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Xin chào,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tôi là Otter!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trợ lý AI của bạn!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nhấn để bắt đầu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXPANDED CARDS OVERLAY (unchanged)
// ============================================================
class _ExpandedCardsOverlay extends StatefulWidget {
  final double dailyLimit;
  final double monthlySalary;
  final DateTime selectedDate;
  final Animation<double> animation;

  const _ExpandedCardsOverlay({
    required this.dailyLimit,
    required this.monthlySalary,
    required this.selectedDate,
    required this.animation,
  });

  @override
  State<_ExpandedCardsOverlay> createState() => _ExpandedCardsOverlayState();
}

class _ExpandedCardsOverlayState extends State<_ExpandedCardsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Start cascade immediately — blur and cards animate together
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  // Cards 1-4 get staggered intervals to slide out from behind card 0
  Animation<double> _cardAnimation(int index) {
    final start = (index - 1) * 0.08;
    final end = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      DailyBalanceCard(
        dailyLimit: widget.dailyLimit,
        selectedDate: widget.selectedDate,
      ),
      SafeBalanceCard(onDeposit: () => DashboardStack.showDepositDialog(context)),
      WeeklySummaryCard(selectedDate: widget.selectedDate),
      SpendingForecastCard(
        dailyLimit: widget.dailyLimit,
        monthlySalary: widget.monthlySalary,
      ),
      const SavingsOverviewCard(),
      MonthlySummaryCard(
        dailyLimit: widget.dailyLimit,
        monthlySalary: widget.monthlySalary,
      ),
    ];

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.animation, _staggerController]),
        builder: (context, _) {
          final fadeT = Curves.easeOut.transform(widget.animation.value);
          return Stack(
            children: [
              // Blur + dark overlay — fades in with dialog transition
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 20 * fadeT,
                    sigmaY: 20 * fadeT,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5 * fadeT),
                  ),
                ),
              ),
              // Cards
              SafeArea(
                child: Column(
                  children: [
                    // Close handle
                    Opacity(
                      opacity: fadeT,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: cards.length + 1,
                        itemBuilder: (context, index) {
                          if (index >= cards.length) {
                            return const SizedBox(height: 80);
                          }

                          if (index == 0) {
                            // First card — immediately visible, stays in place
                            // It appears with the blur (continuous from dashboard)
                            return Opacity(
                              opacity: fadeT,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SizedBox(height: 260, child: cards[0]),
                              ),
                            );
                          }

                          // Cards 1-4: slide out from behind card 0
                          final anim = _cardAnimation(index);
                          final t = anim.value;
                          final slideUp =
                              30.0 * (1.0 - t); // slides up into position
                          final scale = 0.92 + (0.08 * t);

                          return Transform.translate(
                            offset: Offset(0, -slideUp),
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.topCenter,
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: SizedBox(
                                    height: 260,
                                    child: cards[index],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
