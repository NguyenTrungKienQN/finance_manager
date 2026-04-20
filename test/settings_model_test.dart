import 'package:finance_manager/models/settings_model.dart';
import 'package:finance_manager/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mid-month onboarding uses remaining budget across remaining days', () {
    final settings = AppSettings(
      monthlySalary: 10000000,
      trackingStartDate: DateTime(2026, 4, 20),
      initialMonthSpent: 5000000,
    );

    final limit = settings.calculateDailyLimitForDate(
      DateTime(2026, 4, 20),
      const <Transaction>[],
    );

    expect(limit, closeTo(5000000 / 11, 0.1));
  });

  test('mid-month rollover only accrues from the tracking start date', () {
    final settings = AppSettings(
      monthlySalary: 10000000,
      trackingStartDate: DateTime(2026, 4, 20),
      initialMonthSpent: 5000000,
    );

    final limit = settings.calculateDailyLimitForDate(
      DateTime(2026, 4, 21),
      const <Transaction>[],
    );

    expect(limit, closeTo((5000000 / 11) * 2, 0.1));
  });

  test('dates before tracking start do not get a budget allowance', () {
    final settings = AppSettings(
      monthlySalary: 10000000,
      trackingStartDate: DateTime(2026, 4, 20),
      initialMonthSpent: 5000000,
    );

    final limit = settings.calculateDailyLimitForDate(
      DateTime(2026, 4, 19),
      const <Transaction>[],
    );

    expect(limit, 0);
  });
}
