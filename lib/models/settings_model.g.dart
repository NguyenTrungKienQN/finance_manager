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
      dailyLimit: fields[0] as double,
      isFirstInstall: fields[1] as bool,
      userName: fields[2] as String,
      monthlySalary: fields[3] as double,
      themeMode: fields[4] as String,
      freeAiUses: fields[5] as int,
      geminiApiKey: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.geminiApiKey);
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
