import 'package:finance_manager/widgets/home_widgets/modern_home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('habit widget shows provided status text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HabitBreakerHomeWidget(
            habitName: 'Trà sữa',
            streak: 9,
            status: '🧊 Đóng băng · Còn 2 ngày để hồi phục',
          ),
        ),
      ),
    );

    expect(find.text('Trà sữa'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.textContaining('Đóng băng'), findsOneWidget);
  });
}
