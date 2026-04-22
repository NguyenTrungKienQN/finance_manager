// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spending_category_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpendingCategoryAdapter extends TypeAdapter<SpendingCategory> {
  @override
  final int typeId = 7;

  @override
  SpendingCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpendingCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      iconName: fields[2] as String,
      colorValue: fields[3] as int,
      budget: fields[4] as double?,
      budgetPeriod: fields[5] as BudgetPeriod?,
      sortOrder: fields[6] as int,
      isDefault: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SpendingCategory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconName)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.budget)
      ..writeByte(5)
      ..write(obj.budgetPeriod)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BudgetPeriodAdapter extends TypeAdapter<BudgetPeriod> {
  @override
  final int typeId = 8;

  @override
  BudgetPeriod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BudgetPeriod.daily;
      case 1:
        return BudgetPeriod.monthly;
      default:
        return BudgetPeriod.daily;
    }
  }

  @override
  void write(BinaryWriter writer, BudgetPeriod obj) {
    switch (obj) {
      case BudgetPeriod.daily:
        writer.writeByte(0);
        break;
      case BudgetPeriod.monthly:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
