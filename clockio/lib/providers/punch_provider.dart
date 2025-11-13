import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/punch.dart';

class PunchProvider extends ChangeNotifier {
  late Box<Punch> _punchBox;
  List<Punch> _punches = [];

  List<Punch> get punches => _punches;

  void loadPunches() {
    _punchBox = Hive.box<Punch>('punches');
    _punches = _punchBox.values.toList();
    notifyListeners();
  }

  Punch? get todayPunch {
    final today = DateTime.now();
    final matches = _punches.where(
      (p) =>
          p.date.year == today.year &&
          p.date.month == today.month &&
          p.date.day == today.day,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  // ---- Break features ----
  bool get isOnBreak {
    final punch = todayPunch;
    if (punch == null || punch.breaks.isEmpty) return false;
    final last = punch.breaks.last;
    return last.end == null;
  }

  Future<void> startBreak() async {
    final punch = todayPunch;
    if (punch != null) {
      punch.breaks.add(BreakPeriod(start: DateTime.now()));
      await punch.save();
      loadPunches();
    }
  }

  Future<void> endBreak() async {
    final punch = todayPunch;
    if (punch != null &&
        punch.breaks.isNotEmpty &&
        punch.breaks.last.end == null) {
      punch.breaks.last.end = DateTime.now();
      await punch.save();
      loadPunches();
    }
  }

  Duration totalBreakDuration(Punch punch) {
    return punch.breaks.fold(Duration.zero, (sum, b) {
      if (b.end != null) {
        return sum + b.end!.difference(b.start);
      }
      return sum;
    });
  }

  Duration punchDuration(Punch punch) {
    if (punch.timeIn != null && punch.timeOut != null) {
      final worked = punch.timeOut!.difference(punch.timeIn!);
      return worked - totalBreakDuration(punch);
    }
    return Duration.zero;
  }

  Duration totalDurationForDay(DateTime day) {
    final sameDay = _punches.where(
      (p) =>
          p.date.year == day.year &&
          p.date.month == day.month &&
          p.date.day == day.day,
    );
    return sameDay.fold(Duration.zero, (sum, p) => sum + punchDuration(p));
  }

  Future<void> checkIn() async {
    final now = DateTime.now();
    final matches = _punches.where(
      (p) =>
          p.date.year == now.year &&
          p.date.month == now.month &&
          p.date.day == now.day,
    );
    Punch? todayRecord = matches.isNotEmpty ? matches.first : null;
    if (todayRecord == null) {
      await addPunch(Punch(date: now, timeIn: now));
    } else {
      if (todayRecord.timeIn == null) {
        todayRecord.timeIn = now;
        await todayRecord.save();
        loadPunches();
      }
    }
  }

  Future<void> checkOut() async {
    final now = DateTime.now();
    final matches = _punches.where(
      (p) =>
          p.date.year == now.year &&
          p.date.month == now.month &&
          p.date.day == now.day,
    );
    Punch? todayRecord = matches.isNotEmpty ? matches.first : null;
    if (todayRecord != null &&
        todayRecord.timeIn != null &&
        todayRecord.timeOut == null) {
      todayRecord.timeOut = now;
      await todayRecord.save();
      loadPunches();
    }
  }

  List<Punch> get recentPunches {
    _punches.sort((a, b) => b.date.compareTo(a.date));
    return _punches.take(7).toList();
  }

  /// Group punches by a 'YYYY-MM-DD' string for history view (daily grouping)
  Map<String, List<Punch>> get punchesByDay {
    Map<String, List<Punch>> grouped = {};
    for (var p in _punches) {
      final dateKey =
          "${p.date.year}-${p.date.month.toString().padLeft(2, '0')}-${p.date.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateKey, () => []).add(p);
    }
    return grouped;
  }

  /// Group punches by 'YYYY-MM' for monthly report
  Map<String, List<Punch>> get punchesByMonth {
    Map<String, List<Punch>> grouped = {};
    for (var p in _punches) {
      final monthKey =
          "${p.date.year}-${p.date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(monthKey, () => []).add(p);
    }
    return grouped;
  }

  Future<void> addPunch(Punch punch) async {
    await _punchBox.add(punch);
    loadPunches();
  }

  Future<void> updatePunch(int index, Punch punch) async {
    await _punchBox.putAt(index, punch);
    loadPunches();
  }

  Future<void> deletePunch(Punch punch) async {
    await punch.delete();
    loadPunches();
  }

  Future<void> updatePunchTimes(Punch punch, {DateTime? timeIn, DateTime? timeOut}) async {
    if (timeIn != null) {
      punch.timeIn = timeIn;
    }
    if (timeOut != null) {
      punch.timeOut = timeOut;
    }
    await punch.save();
    loadPunches();
  }

  Future<void> addBreak(Punch punch, BreakPeriod breakPeriod) async {
    punch.breaks.add(breakPeriod);
    await punch.save();
    loadPunches();
  }

  Future<void> updateBreak(Punch punch, int index, {DateTime? start, DateTime? end}) async {
    if (index < 0 || index >= punch.breaks.length) return;
    final breakPeriod = punch.breaks[index];
    if (start != null) {
      breakPeriod.start = start;
    }
    if (end != null) {
      breakPeriod.end = end;
    }
    await punch.save();
    loadPunches();
  }

  Future<void> deleteBreak(Punch punch, int index) async {
    if (index < 0 || index >= punch.breaks.length) return;
    punch.breaks.removeAt(index);
    await punch.save();
    loadPunches();
  }

  // ---- Reports & Statistics ----
  List<Punch> getPunchesForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _punches.where((p) {
      return p.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          p.date.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();
  }

  List<Punch> getPunchesForMonth(int year, int month) {
    return _punches.where((p) {
      return p.date.year == year && p.date.month == month;
    }).toList();
  }

  Duration totalDurationForWeek(DateTime weekStart) {
    return getPunchesForWeek(weekStart)
        .fold(Duration.zero, (sum, p) => sum + punchDuration(p));
  }

  Duration totalDurationForMonth(int year, int month) {
    return getPunchesForMonth(year, month)
        .fold(Duration.zero, (sum, p) => sum + punchDuration(p));
  }

  double averageHoursPerWeek(DateTime weekStart) {
    final weekPunches = getPunchesForWeek(weekStart);
    if (weekPunches.isEmpty) return 0.0;
    final total = totalDurationForWeek(weekStart);
    return total.inMinutes / 60.0;
  }

  double averageHoursPerMonth(int year, int month) {
    final monthPunches = getPunchesForMonth(year, month);
    if (monthPunches.isEmpty) return 0.0;
    final total = totalDurationForMonth(year, month);
    return total.inMinutes / 60.0;
  }

  Map<DateTime, Duration> getWeeklyChartData(DateTime weekStart) {
    final Map<DateTime, Duration> data = {};
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      data[day] = totalDurationForDay(day);
    }
    return data;
  }

  Map<int, Duration> getMonthlyChartData(int year, int month) {
    final Map<int, Duration> data = {};
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      data[day] = totalDurationForDay(date);
    }
    return data;
  }

  String exportToCSV({DateTime? startDate, DateTime? endDate}) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Time In,Time Out,Duration (hours),Breaks');
    final filtered = startDate != null && endDate != null
        ? _punches.where((p) =>
            p.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            p.date.isBefore(endDate.add(const Duration(days: 1))))
        : _punches;
    for (var punch in filtered) {
      final dateStr = DateFormat('yyyy-MM-dd').format(punch.date);
      final timeInStr = punch.timeIn != null
          ? DateFormat('HH:mm:ss').format(punch.timeIn!)
          : '';
      final timeOutStr = punch.timeOut != null
          ? DateFormat('HH:mm:ss').format(punch.timeOut!)
          : '';
      final durationHours = punchDuration(punch).inMinutes / 60.0;
      final breaksCount = punch.breaks.length;
      buffer.writeln(
          '$dateStr,$timeInStr,$timeOutStr,$durationHours,$breaksCount');
    }
    return buffer.toString();
  }
}
