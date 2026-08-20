import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicCatcherApp());
}

class MusicCatcherApp extends StatelessWidget {
  const MusicCatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicCatcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1DB954),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1DB954),
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        cardColor: const Color(0xFF1A1A2E),
      ),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
