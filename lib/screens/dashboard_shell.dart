import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import 'workout/workout_tab.dart';
import 'diet/diet_tab.dart';
import 'analytics/analytics_screen.dart';
import 'profile/profile_screen.dart';
import 'scan/scan_selection_screen.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const WorkoutTab(),
    const DietTab(),
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomAppBar(
        color: isDark ? FuelixTheme.darkCard : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 10,
        padding: EdgeInsets.zero,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.fitness_center_rounded, 'Workout', isDark),
            _buildNavItem(1, Icons.restaurant_menu_rounded, 'Diet', isDark),
            const SizedBox(width: 48), // Space for floating action button
            _buildNavItem(2, Icons.insights_rounded, 'Analytics', isDark),
            _buildNavItem(3, Icons.person_rounded, 'Profile', isDark),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanSelectionScreen()),
          );
        },
        backgroundColor: FuelixTheme.accentOrange,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected 
        ? FuelixTheme.accentOrange 
        : (isDark ? FuelixTheme.textLightSecondary : FuelixTheme.textDarkSecondary);
        
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
