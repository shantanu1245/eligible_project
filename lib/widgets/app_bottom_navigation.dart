import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,

      height: 68,

      backgroundColor: Colors.white,

      indicatorColor:
          const Color(0xFFDBEAFE),

      labelBehavior:
          NavigationDestinationLabelBehavior
              .alwaysShow,

      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.dashboard_outlined,
          ),
          selectedIcon: Icon(
            Icons.dashboard_rounded,
            color: AppTheme.primary,
          ),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.people_outline_rounded,
          ),
          selectedIcon: Icon(
            Icons.people_rounded,
            color: AppTheme.primary,
          ),
          label: 'Leads',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.event_note_outlined,
          ),
          selectedIcon: Icon(
            Icons.event_note_rounded,
            color: AppTheme.primary,
          ),
          label: 'Follow-ups',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.bar_chart_outlined,
          ),
          selectedIcon: Icon(
            Icons.bar_chart_rounded,
            color: AppTheme.primary,
          ),
          label: 'Analytics',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.more_horiz_rounded,
          ),
          selectedIcon: Icon(
            Icons.more_horiz_rounded,
            color: AppTheme.primary,
          ),
          label: 'More',
        ),
      ],
    );
  }
}