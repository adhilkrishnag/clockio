import 'package:hive/hive.dart';

part 'punch.g.dart';

@HiveType(typeId: 1)
class BreakPeriod extends HiveObject {
  @HiveField(0)
  DateTime start;

  @HiveField(1)
  DateTime? end;

  BreakPeriod({required this.start, this.end});
}

@HiveType(typeId: 0)
class Punch extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  DateTime? timeIn;

  @HiveField(2)
  DateTime? timeOut;

  @HiveField(3)
  List<BreakPeriod> breaks;

  Punch({required this.date, this.timeIn, this.timeOut, List<BreakPeriod>? breaks}) : breaks = breaks ?? [];
}
