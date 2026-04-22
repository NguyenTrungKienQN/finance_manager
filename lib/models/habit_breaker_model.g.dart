// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_breaker_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitBreakerAdapter extends TypeAdapter<HabitBreaker> {
  @override
  final int typeId = 6;

  @override
  HabitBreaker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitBreaker(
      id: fields[0] as String,
      habitName: fields[1] as String,
      iconName: fields[2] as String,
      startDate: fields[3] as DateTime?,
      currentStreak: fields[4] as int,
      bestStreak: fields[5] as int,
      lastCheckDate: fields[6] as DateTime?,
      isActive: fields[7] as bool,
      badges: (fields[8] as List?)?.cast<String>(),
      streakTier: fields[9] == null ? 'regular' : fields[9] as String,
      hasShield: fields[10] == null ? false : fields[10] as bool,
      isFrozen: fields[11] == null ? false : fields[11] as bool,
      frozenDate: fields[12] as DateTime?,
      wasPurpleBeforeFreeze: fields[13] == null ? false : fields[13] as bool,
      cleanDaysSinceRecovery: fields[14] == null ? 0 : fields[14] as int,
      dayStates: fields[15] == null
          ? {}
          : (fields[15] as Map?)?.cast<String, String>(),
      targetDuration: fields[16] as int?,
      aiPersona: fields[17] == null ? 'expert' : fields[17] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HabitBreaker obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.habitName)
      ..writeByte(2)
      ..write(obj.iconName)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.currentStreak)
      ..writeByte(5)
      ..write(obj.bestStreak)
      ..writeByte(6)
      ..write(obj.lastCheckDate)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.badges)
      ..writeByte(9)
      ..write(obj.streakTier)
      ..writeByte(10)
      ..write(obj.hasShield)
      ..writeByte(11)
      ..write(obj.isFrozen)
      ..writeByte(12)
      ..write(obj.frozenDate)
      ..writeByte(13)
      ..write(obj.wasPurpleBeforeFreeze)
      ..writeByte(14)
      ..write(obj.cleanDaysSinceRecovery)
      ..writeByte(15)
      ..write(obj.dayStates)
      ..writeByte(16)
      ..write(obj.targetDuration)
      ..writeByte(17)
      ..write(obj.aiPersona);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitBreakerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
