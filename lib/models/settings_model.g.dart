// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      dailyLimit: fields[0] == null ? 500000.0 : fields[0] as double,
      isFirstInstall: fields[1] == null ? true : fields[1] as bool,
      userName: fields[2] == null ? 'Bạn' : fields[2] as String,
      monthlySalary: fields[3] == null ? 15000000.0 : fields[3] as double,
      themeMode: fields[4] == null ? 'system' : fields[4] as String,
      freeAiUses: fields[5] == null ? 5 : fields[5] as int,
      geminiApiKey: fields[6] as String?,
      hasSeenOtterIntro: fields[7] == null ? false : fields[7] as bool,
      notifMorningBudget: fields[8] == null ? true : fields[8] as bool,
      notifOverspendAlert: fields[9] == null ? true : fields[9] as bool,
      notifHabitStreak: fields[10] == null ? true : fields[10] as bool,
      notifEveningSummary: fields[11] == null ? false : fields[11] as bool,
      notifWeeklyInsight: fields[12] == null ? false : fields[12] as bool,
      notifDebtReminder: fields[13] == null ? false : fields[13] as bool,
      notifEndOfMonth: fields[14] == null ? false : fields[14] as bool,
      notifSavingsMilestone: fields[15] == null ? false : fields[15] as bool,
      enableAppLock: fields[16] == null ? false : fields[16] as bool,
      safeBalance: fields[17] == null ? 0.0 : fields[17] as double,
      trackingStartDate: fields[18] as DateTime?,
      initialMonthSpent: fields[19] == null ? 0.0 : fields[19] as double,
      headerBackgroundImagePath: fields[20] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.dailyLimit)
      ..writeByte(1)
      ..write(obj.isFirstInstall)
      ..writeByte(2)
      ..write(obj.userName)
      ..writeByte(3)
      ..write(obj.monthlySalary)
      ..writeByte(4)
      ..write(obj.themeMode)
      ..writeByte(5)
      ..write(obj.freeAiUses)
      ..writeByte(6)
      ..write(obj.geminiApiKey)
      ..writeByte(7)
      ..write(obj.hasSeenOtterIntro)
      ..writeByte(8)
      ..write(obj.notifMorningBudget)
      ..writeByte(9)
      ..write(obj.notifOverspendAlert)
      ..writeByte(10)
      ..write(obj.notifHabitStreak)
      ..writeByte(11)
      ..write(obj.notifEveningSummary)
      ..writeByte(12)
      ..write(obj.notifWeeklyInsight)
      ..writeByte(13)
      ..write(obj.notifDebtReminder)
      ..writeByte(14)
      ..write(obj.notifEndOfMonth)
      ..writeByte(15)
      ..write(obj.notifSavingsMilestone)
      ..writeByte(16)
      ..write(obj.enableAppLock)
      ..writeByte(17)
      ..write(obj.safeBalance)
      ..writeByte(18)
      ..write(obj.trackingStartDate)
      ..writeByte(19)
      ..write(obj.initialMonthSpent)
      ..writeByte(20)
      ..write(obj.headerBackgroundImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
