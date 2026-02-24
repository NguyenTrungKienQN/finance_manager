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
    );
  }

  @override
  void write(BinaryWriter writer, HabitBreaker obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.badges);
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
