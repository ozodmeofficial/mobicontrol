import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const MobiControlApp());
}

class MobiControlApp extends StatelessWidget {
  const MobiControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
    return MaterialApp(
      title: 'MobiControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
