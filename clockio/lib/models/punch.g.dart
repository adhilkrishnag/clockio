// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'punch.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BreakPeriodAdapter extends TypeAdapter<BreakPeriod> {
  @override
  final int typeId = 1;

  @override
  BreakPeriod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BreakPeriod(
      start: fields[0] as DateTime,
      end: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BreakPeriod obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.start)
      ..writeByte(1)
      ..write(obj.end);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakPeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PunchAdapter extends TypeAdapter<Punch> {
  @override
  final int typeId = 0;

  @override
  Punch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Punch(
      date: fields[0] as DateTime,
      timeIn: fields[1] as DateTime?,
      timeOut: fields[2] as DateTime?,
      breaks: (fields[3] as List?)?.cast<BreakPeriod>(),
    );
  }

  @override
  void write(BinaryWriter writer, Punch obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.timeIn)
      ..writeByte(2)
      ..write(obj.timeOut)
      ..writeByte(3)
      ..write(obj.breaks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PunchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
