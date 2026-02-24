import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stacked_card_carousel/stacked_card_carousel.dart';
import 'daily_balance_card.dart';
import 'weekly_summary_card.dart';
import 'spending_forecast_card.dart';
import 'savings_overview_card.dart';
import 'monthly_summary_card.dart';

class DashboardStack extends StatelessWidget {
  final double dailyLimit;
  final double monthlySalary;
  final DateTime selectedDate;

  const DashboardStack({
    super.key,
    required this.dailyLimit,
    required this.monthlySalary,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width - 40;
    const double cardHeight = 240.0;

    final List<Widget> cards = [
      _buildCard(
        context,
        DailyBalanceCard(dailyLimit: dailyLimit, selectedDate: selectedDate),
        cardWidth,
        cardHeight,
      ),
      _buildCard(
        context,
        WeeklySummaryCard(selectedDate: selectedDate),
        cardWidth,
        cardHeight,
      ),
      _buildCard(
        context,
        SpendingForecastCard(
          dailyLimit: dailyLimit,
          monthlySalary: monthlySalary,
        ),
        cardWidth,
        cardHeight,
      ),
      _buildCard(context, const SavingsOverviewCard(), cardWidth, cardHeight),
      _buildCard(
        context,
        MonthlySummaryCard(
          dailyLimit: dailyLimit,
          monthlySalary: monthlySalary,
        ),
        cardWidth,
        cardHeight,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: cardHeight + 20,
        child: StackedCardCarousel(
          items: cards,
          spaceBetweenItems: cardHeight,
          initialOffset: 0,
          type: StackedCardCarouselType.cardsStack,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Widget child,
    double width,
    double height,
  ) {
    return GestureDetector(
      onTap: () => _showExpandedCards(context),
      child: SizedBox(height: height, width: width, child: child),
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
          dailyLimit: dailyLimit,
          monthlySalary: monthlySalary,
          selectedDate: selectedDate,
          animation: anim1,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) => child,
    );
  }
}

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
