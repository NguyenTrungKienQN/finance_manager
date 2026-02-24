// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringTransactionAdapter extends TypeAdapter<RecurringTransaction> {
  @override
  final int typeId = 3;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      dayOfMonth: fields[3] as int,
      isExpense: fields[4] as bool,
      lastPaidDate: fields[5] as DateTime?,
      isActive: fields[6] as bool,
      frequency: fields[7] == null
          ? RecurringFrequency.monthly
          : fields[7] as RecurringFrequency,
      monthOfYear: fields[8] as int?,
      interval: fields[9] == null ? 1 : fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dayOfMonth)
      ..writeByte(4)
      ..write(obj.isExpense)
      ..writeByte(5)
      ..write(obj.lastPaidDate)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.frequency)
      ..writeByte(8)
      ..write(obj.monthOfYear)
      ..writeByte(9)
      ..write(obj.interval);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecurringFrequencyAdapter extends TypeAdapter<RecurringFrequency> {
  @override
  final int typeId = 4;

  @override
  RecurringFrequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecurringFrequency.monthly;
      case 1:
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.monthly;
    }
  }

  @override
  void write(BinaryWriter writer, RecurringFrequency obj) {
    switch (obj) {
      case RecurringFrequency.monthly:
        writer.writeByte(0);
        break;
      case RecurringFrequency.yearly:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringFrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
