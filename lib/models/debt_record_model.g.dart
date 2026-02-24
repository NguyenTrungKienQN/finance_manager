// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtRecordAdapter extends TypeAdapter<DebtRecord> {
  @override
  final int typeId = 5;

  @override
  DebtRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DebtRecord(
      id: fields[0] as String,
      debtorName: fields[1] as String,
      amount: fields[2] as double,
      description: fields[3] as String,
      date: fields[4] as DateTime,
      isPaid: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DebtRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.debtorName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.isPaid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
