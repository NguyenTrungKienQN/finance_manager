// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncomeRecordAdapter extends TypeAdapter<IncomeRecord> {
  @override
  final int typeId = 9;

  @override
  IncomeRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IncomeRecord(
      id: fields[0] as String,
      month: fields[1] as int,
      year: fields[2] as int,
      name: fields[3] as String,
      amount: fields[4] as double,
      isRecurring: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, IncomeRecord obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.month)
      ..writeByte(2)
      ..write(obj.year)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.isRecurring)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
