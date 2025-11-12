import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/punch.dart';
import 'providers/punch_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(PunchAdapter());
  Hive.registerAdapter(BreakPeriodAdapter());
  await Hive.openBox<Punch>('punches');
  runApp(const ClockioApp());
}

class ClockioApp extends StatelessWidget {
  const ClockioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PunchProvider()..loadPunches()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Clockio',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              brightness: themeProvider.isDark
                  ? Brightness.dark
                  : Brightness.light,
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
