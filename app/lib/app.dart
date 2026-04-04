import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/video_analysis_screen.dart';
import 'screens/manual_analysis_screen.dart';

class MeeHawkApp extends StatelessWidget {
  const MeeHawkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeeHawk',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('MeeHawk',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent)),
            const SizedBox(width: 12),
            Text('Volleyball Video Analysis',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Manual Analysis'),
            Tab(text: 'Video Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ManualAnalysisScreen(),
          VideoAnalysisScreen(),
        ],
      ),
    );
  }
}
