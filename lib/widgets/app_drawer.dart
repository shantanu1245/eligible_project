import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../screens/campaigns_screen.dart';
import '../screens/lead_allotment_screen.dart';
import '../screens/login_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/team_screen.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;
  final int currentTabIndex;
  final Function(int) onTabSelected;
  final List<Lead> leads;
  final Function(List<Lead>) onLeadsUpdated;

  const AppDrawer({
    super.key,
    required this.user,
    required this.currentTabIndex,
    required this.onTabSelected,
    required this.leads,
    required this.onLeadsUpdated,
  });

  int get _unassignedCount =>
      leads.where((l) => l.assignedTo.trim().isEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            _buildUserHeader(context),

            const Divider(height: 1, color: AppTheme.border),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _drawerItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    isSelected: currentTabIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelected(0);
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.people_outline_rounded,
                    selectedIcon: Icons.people_rounded,
                    title: user.isAdmin ? 'All Leads' : 'My Leads',
                    isSelected: currentTabIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelected(1);
                    },
                  ),

                  // Lead Allotment (Administrator only)
                  if (user.isAdmin) ...[
                    _drawerItem(
                      context: context,
                      icon: Icons.assignment_ind_outlined,
                      selectedIcon: Icons.assignment_ind_rounded,
                      title: 'Lead Allotment',
                      badge: _unassignedCount > 0
                          ? '$_unassignedCount unassigned'
                          : null,
                      badgeColor: const Color(0xFFDC2626),
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeadAllotmentScreen(
                              leads: leads,
                              onLeadsUpdated: onLeadsUpdated,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  _drawerItem(
                    context: context,
                    icon: Icons.event_note_outlined,
                    selectedIcon: Icons.event_note_rounded,
                    title: 'Follow-ups',
                    isSelected: currentTabIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelected(2);
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.bar_chart_outlined,
                    selectedIcon: Icons.bar_chart_rounded,
                    title: 'Analytics',
                    isSelected: currentTabIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelected(3);
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.task_alt_outlined,
                    selectedIcon: Icons.task_alt_rounded,
                    title: 'Tasks',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TasksScreen(),
                        ),
                      );
                    },
                  ),

                  // Admin-Only Workspace Tools
                  if (user.isAdmin) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        'ADMIN TOOLS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _drawerItem(
                      context: context,
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      title: 'Team Management',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TeamScreen(),
                          ),
                        );
                      },
                    ),
                    _drawerItem(
                      context: context,
                      icon: Icons.campaign_outlined,
                      selectedIcon: Icons.campaign,
                      title: 'Ad Campaigns',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CampaignsScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  const Divider(height: 16, color: AppTheme.border),

                  _drawerItem(
                    context: context,
                    icon: Icons.more_horiz_rounded,
                    selectedIcon: Icons.more_horiz_rounded,
                    title: 'More & Settings',
                    isSelected: currentTabIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      onTabSelected(4);
                    },
                  ),
                ],
              ),
            ),

            // Logout Footer
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Brand & Icon
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: AppTheme.primary,
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eligible CRM',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Smart Sales Engine',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),

          // User Info
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: user.isAdmin
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFDCFCE7),
                child: Text(
                  user.initial,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: user.isAdmin
                        ? AppTheme.primary
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isAdmin
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: user.isAdmin
                              ? const Color(0xFFBFDBFE)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Text(
                        user.roleDisplayName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: user.isAdmin
                              ? AppTheme.primary
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppTheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: badgeColor ?? AppTheme.primary,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor ?? AppTheme.primary,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}