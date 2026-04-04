import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

class MeeHawkApp extends StatelessWidget {
  const MeeHawkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeeHawk',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
