import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/punch_provider.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showCheckAnim = false;
  Timer? _timer;
  String userName = 'Your Name';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _loadUserName();
    _startLiveTimerIfNeeded();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'Your Name';
    });
  }

  Future<void> _saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    setState(() {
      userName = name;
    });
  }

  void _editNameDialog() {
    final controller = TextEditingController(text: userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Your Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) _saveUserName(name);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Start a ticker if clocked in (not out) or currently on break
  void _startLiveTimerIfNeeded() {
    _timer?.cancel();
    final provider = context.read<PunchProvider>();
    final today = provider.todayPunch;
    final needTimer =
        (today?.timeIn != null && today?.timeOut == null) || provider.isOnBreak;
    if (needTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _restartTimerOnAction() {
    _timer?.cancel();
    _startLiveTimerIfNeeded();
  }

  void _triggerCheckAnim() {
    setState(() => _showCheckAnim = true);
    _controller.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        setState(() => _showCheckAnim = false);
      });
    });
  }

  String _timeString(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('h:mm a').format(dateTime); // e.g., 1:05 PM
  }

  String _durationString(Duration dur) {
    if (dur.inSeconds == 0) return '0 s';
    final h = dur.inHours;
    final m = dur.inMinutes.remainder(60);
    final s = dur.inSeconds.remainder(60);
    final buf = <String>[];
    if (h > 0) buf.add('$h h');
    if (m > 0) buf.add('$m m');
    if (s > 0 && h == 0) buf.add('$s s');
    return buf.join(' ');
  }

  String _dateString(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat(
      'E, MMM d yyyy',
    ).format(dateTime); // e.g., Wed, Jun 5 2025
  }

  void _showHistorySheet(
    BuildContext context,
    Map<String, List<dynamic>> log,
    PunchProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(20),
        children: log.entries.map((entry) {
          final total = entry.value.fold(
            Duration.zero,
            (sum, punch) => sum + provider.punchDuration(punch),
          );
          // Parse YYYY-MM-DD to DateTime for pretty formatting
          final dateObj = DateTime.tryParse(entry.key);
          final displayKey = dateObj != null ? _dateString(dateObj) : entry.key;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayKey,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              ...entry.value.asMap().entries.map((e) {
                final punch = e.value;
                final isBreak =
                    punch.timeIn != null && punch.timeOut != null && e.key > 0;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isBreak
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.blue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBreak ? Icons.hourglass_bottom : Icons.fingerprint,
                        color: isBreak
                            ? Colors.orange.shade400
                            : Colors.blue.shade600,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'In: ${_timeString(punch.timeIn)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Out: ${_timeString(punch.timeOut)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Dur: ${_durationString(provider.punchDuration(punch))}',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Total: ${_durationString(total)}',
                  style: TextStyle(
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PunchProvider, ThemeProvider>(
      builder: (context, provider, themeProvider, _) {
        final today = provider.todayPunch;
        final totalToday = today != null
            ? provider.totalDurationForDay(today.date)
            : Duration.zero;
        final isOnBreak = provider.isOnBreak;
        final canCheckIn = today?.timeIn == null;
        final canStartBreak =
            today != null &&
            today.timeIn != null &&
            today.timeOut == null &&
            !isOnBreak;
        final canEndBreak = today != null && isOnBreak;
        final canCheckOut =
            today?.timeIn != null && today?.timeOut == null && !isOnBreak;
        final breaks = today?.breaks ?? [];
        // Ensure correct timer state on every build
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _startLiveTimerIfNeeded(),
        );

        Duration liveWorkDuration = Duration.zero;
        if (today != null && today.timeIn != null) {
          if (today.timeOut != null) {
            liveWorkDuration = provider.punchDuration(today);
          } else {
            // Not clocked out: calculate net worked so far
            final now = DateTime.now();
            final workedSoFar = now.difference(today.timeIn!);
            final breaksDuration = provider.totalBreakDuration(today);
            // If currently on break, subtract ongoing break duration
            Duration ongoingBreak = Duration.zero;
            if (provider.isOnBreak &&
                breaks.isNotEmpty &&
                breaks.last.end == null) {
              ongoingBreak = now.difference(breaks.last.start);
            }
            liveWorkDuration = workedSoFar - (breaksDuration + ongoingBreak);
          }
        }

        Duration currentBreakDuration = Duration.zero;
        if (isOnBreak && breaks.isNotEmpty) {
          currentBreakDuration = DateTime.now().difference(breaks.last.start);
        }

        return Scaffold(
          backgroundColor: themeProvider.isDark
              ? Colors.black
              : const Color(0xFFF3F7FA),
          appBar: AppBar(
            title: const Text('Clockio Home'),
            backgroundColor: Colors.blue[700],
            elevation: 0,
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
          ),
          drawer: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Drawer(
              backgroundColor: themeProvider.isDark
                  ? Colors.grey[900]
                  : Colors.white,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _editNameDialog,
                      child: Container(
                        width: double.infinity,
                        color: Colors.blue[100],
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.blue[400],
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to edit',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.timeline, color: Colors.blue[700]),
                      title: const Text('Timeline'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Future implementation: Go to Timeline screen
                      },
                    ),
                    SwitchListTile(
                      secondary: Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                      title: const Text('Dark Mode'),
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.settings,
                        color: Colors.blueGrey[700],
                      ),
                      title: const Text('Settings'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Future: Settings screen
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: Colors.green[800],
                      ),
                      title: const Text('About'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Future: About screen
                      },
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Text(
                        'Clockio v1.0 – All rights reserved.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Card(
                      color: Colors.blue[50],
                      elevation: 7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.blue[600],
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Today's Punch",
                                  style: Theme.of(context).textTheme.titleLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Time In   : ${_timeString(today?.timeIn)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            Text(
                              'Time Out: ${_timeString(today?.timeOut)}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              // Live net work duration
                              'Duration: ${_durationString(liveWorkDuration > Duration.zero ? liveWorkDuration : Duration.zero)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Today: ${_durationString(totalToday)}',
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (isOnBreak)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Current Break: ${_durationString(currentBreakDuration)}',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            if (breaks.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                "Breaks:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                  fontSize: 15,
                                ),
                              ),
                              for (var i = 0; i < breaks.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        breaks[i].end == null
                                            ? Icons.hourglass_empty
                                            : Icons.hourglass_full,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Break ${i + 1}: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(_timeString(breaks[i].start)),
                                      const Text(' - '),
                                      Text(
                                        breaks[i].end != null
                                            ? _timeString(breaks[i].end)
                                            : '...',
                                      ),
                                      const SizedBox(width: 10),
                                      if (breaks[i].end != null)
                                        Text(
                                          _durationString(
                                            breaks[i].end!.difference(
                                              breaks[i].start,
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: Colors.teal[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      if (breaks[i].end == null && isOnBreak)
                                        Text(
                                          '(${_durationString(currentBreakDuration)})',
                                          style: const TextStyle(
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      if (breaks[i].end == null && !isOnBreak)
                                        const Text(
                                          '(Active)',
                                          style: TextStyle(
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_showCheckAnim)
                      ScaleTransition(
                        scale: _animation,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 20),
                          child: Icon(
                            Icons.celebration_rounded,
                            color: Colors.green.shade700,
                            size: 34,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: canCheckIn
                          ? () async {
                              await provider.checkIn();
                              _triggerCheckAnim();
                              _restartTimerOnAction();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 7),
                          const Text('Time In'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: canStartBreak
                          ? () async {
                              await provider.startBreak();
                              _restartTimerOnAction();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.free_breakfast_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 7),
                          const Text('Start Break'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: canEndBreak
                          ? () async {
                              await provider.endBreak();
                              _restartTimerOnAction();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 7),
                          const Text('End Break'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: canCheckOut
                          ? () async {
                              await provider.checkOut();
                              _triggerCheckAnim();
                              _restartTimerOnAction();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 22),
                          const SizedBox(width: 7),
                          const Text('Time Out'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Records',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: provider.recentPunches.isEmpty
                          ? null
                          : () => _showHistorySheet(
                              context,
                              provider.punchesByDay,
                              provider,
                            ),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text("Full Log"),
                    ),
                  ],
                ),
                Expanded(
                  child: AnimatedList(
                    key: ValueKey(provider.recentPunches.length),
                    initialItemCount: provider.recentPunches.length,
                    itemBuilder: (ctx, idx, anim) {
                      final punch = provider.recentPunches[idx];
                      return SizeTransition(
                        sizeFactor: anim,
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 2,
                          ),
                          elevation: 2.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.blueAccent,
                              ),
                            ),
                            title: Text(
                              _dateString(punch.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'In: ',
                                      style: TextStyle(
                                        color: Colors.blueGrey[600],
                                      ),
                                    ),
                                    Text(
                                      _timeString(punch.timeIn),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Out: ',
                                      style: TextStyle(
                                        color: Colors.blueGrey[600],
                                      ),
                                    ),
                                    Text(
                                      _timeString(punch.timeOut),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Duration: ${_durationString(provider.punchDuration(punch))}',
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
