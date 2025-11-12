import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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
}
