import 'dart:io';

import 'package:finance_manager/models/habit_breaker_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<HabitBreaker> box;

  DateTime dateOnlyNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<HabitBreaker> putHabit(HabitBreaker habit) async {
    await box.add(habit);
    return box.values.last;
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('habit_breaker_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(HabitBreakerAdapter());
    }
    box = await Hive.openBox<HabitBreaker>('habitBreakers_test');
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('habitBreakers_test');
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('regular relapse enters freeze and preserves streak', () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: '1',
        habitName: 'Trà sữa',
        currentStreak: 5,
        bestStreak: 5,
        lastCheckDate: today,
      ),
    );

    final result = habit.handleRelapse();

    expect(result, RelapseResult.frozen);
    expect(habit.isFrozen, isTrue);
    expect(habit.currentStreak, 5);
    expect(habit.freezeDaysRemaining, 3);
    expect(habit.dayStateFor(today), 'frozen');
  });

  test('legacy streaks upgrade into purple tier with shield', () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: 'legacy',
        habitName: 'Trà sữa',
        currentStreak: 9,
        bestStreak: 9,
        lastCheckDate: today,
      ),
    );

    expect(habit.streakTier, HabitBreaker.tierPurple);
    expect(habit.hasShield, isTrue);
    expect(habit.dayStateFor(today), 'clean');
    expect(habit.dayStates.length, greaterThanOrEqualTo(7));
  });

  test('relapse during freeze causes full reset', () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: '2',
        habitName: 'Cà phê',
        currentStreak: 6,
        bestStreak: 8,
        lastCheckDate: today.subtract(const Duration(days: 1)),
        isFrozen: true,
        frozenDate: today.subtract(const Duration(days: 1)),
      ),
    );

    final result = habit.handleRelapse();

    expect(result, RelapseResult.fullReset);
    expect(habit.currentStreak, 0);
    expect(habit.isFrozen, isFalse);
    expect(habit.streakTier, HabitBreaker.tierRegular);
    expect(habit.dayStateFor(today), 'reset');
  });

  test('purple with shield relapse consumes shield without freezing', () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: '3',
        habitName: 'Game',
        currentStreak: 10,
        bestStreak: 10,
        lastCheckDate: today,
        streakTier: HabitBreaker.tierPurple,
        hasShield: true,
      ),
    );

    final result = habit.handleRelapse();

    expect(result, RelapseResult.shieldAbsorbed);
    expect(habit.isFrozen, isFalse);
    expect(habit.currentStreak, 10);
    expect(habit.streakTier, HabitBreaker.tierPurple);
    expect(habit.hasShield, isFalse);
    expect(habit.dayStateFor(today), 'shield_used');
  });

  test('purple without shield relapse enters frozen purple recovery path',
      () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: '4',
        habitName: 'Mua sắm',
        currentStreak: 11,
        bestStreak: 11,
        lastCheckDate: today,
        streakTier: HabitBreaker.tierPurple,
        hasShield: false,
      ),
    );

    final result = habit.handleRelapse();

    expect(result, RelapseResult.frozen);
    expect(habit.isFrozen, isTrue);
    expect(habit.wasPurpleBeforeFreeze, isTrue);
    expect(habit.streakTier, HabitBreaker.tierRegular);
    expect(habit.currentStreak, 11);
  });

  test(
    'frozen purple recovers to regular and needs 7 clean days to re-upgrade',
    () async {
      final today = dateOnlyNow();
      final frozenHabit = await putHabit(
        HabitBreaker(
          id: '5',
          habitName: 'Snack đêm',
          currentStreak: 12,
          bestStreak: 12,
          lastCheckDate: today.subtract(const Duration(days: 3)),
          isFrozen: true,
          frozenDate: today.subtract(const Duration(days: 3)),
          wasPurpleBeforeFreeze: true,
        ),
      );

      frozenHabit.advanceStreak();

      expect(frozenHabit.isFrozen, isFalse);
      expect(frozenHabit.streakTier, HabitBreaker.tierRegular);
      expect(frozenHabit.currentStreak, 12);
      expect(frozenHabit.cleanDaysSinceRecovery, 0);
      expect(frozenHabit.wasPurpleBeforeFreeze, isTrue);

      final recoveredHabit = await putHabit(
        HabitBreaker(
          id: '6',
          habitName: 'Trà chiều',
          currentStreak: 12,
          bestStreak: 12,
          lastCheckDate: today.subtract(const Duration(days: 7)),
          streakTier: HabitBreaker.tierRegular,
          wasPurpleBeforeFreeze: true,
          cleanDaysSinceRecovery: 0,
        ),
      );

      recoveredHabit.advanceStreak();

      expect(recoveredHabit.streakTier, HabitBreaker.tierPurple);
      expect(recoveredHabit.hasShield, isTrue);
      expect(recoveredHabit.cleanDaysSinceRecovery, 0);
      expect(recoveredHabit.wasPurpleBeforeFreeze, isFalse);
    },
  );

  test('frozen days do not increment streak', () async {
    final today = dateOnlyNow();
    final habit = await putHabit(
      HabitBreaker(
        id: '7',
        habitName: 'Bánh ngọt',
        currentStreak: 9,
        bestStreak: 9,
        lastCheckDate: today.subtract(const Duration(days: 2)),
        isFrozen: true,
        frozenDate: today.subtract(const Duration(days: 2)),
      ),
    );

    habit.advanceStreak();

    expect(habit.currentStreak, 9);
    expect(habit.isFrozen, isTrue);
    expect(habit.dayStateFor(today), 'frozen');
  });

  test('dayStates remain accurate and prune old entries', () async {
    final today = dateOnlyNow();
    final oldDate = today.subtract(const Duration(days: 40));
    final oldKey = '${oldDate.year.toString().padLeft(4, '0')}-'
        '${oldDate.month.toString().padLeft(2, '0')}-'
        '${oldDate.day.toString().padLeft(2, '0')}';
    final habit = await putHabit(
      HabitBreaker(
        id: '8',
        habitName: 'Nước ngọt',
        currentStreak: 6,
        bestStreak: 6,
        lastCheckDate: today.subtract(const Duration(days: 1)),
        dayStates: {oldKey: 'clean'},
      ),
    );

    habit.advanceStreak();

    expect(habit.dayStateFor(today), anyOf('clean', 'upgrade'));
    expect(habit.dayStates.containsKey(oldKey), isFalse);
  });
}
