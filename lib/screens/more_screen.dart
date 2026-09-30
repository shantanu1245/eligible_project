import 'package:flutter/material.dart';

import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'add_lead_screen.dart';
import 'campaigns_screen.dart';
import 'integrations_screen.dart';
import 'meta_setup_screen.dart';
import 'notifications_screen.dart';
import 'lead_allotment_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';
import 'team_screen.dart';

class MoreScreen extends StatelessWidget {
  final UserModel user;
  final List<Lead> leads;
  final Function(List<Lead>) onLeadsUpdated;

  const MoreScreen({
    super.key,
    this.user = UserModel.admin,
    this.leads = const [],
    required this.onLeadsUpdated,
  });

  int get _unassignedCount =>
      leads.where((l) => l.assignedTo.trim().isEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'More',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          _buildProfile(context),

          const SizedBox(height: 18),

          _sectionTitle('Workspace'),

          _menuCard([
            // Administrator-only Add New Lead
            if (user.isAdmin)
              _MenuItem(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add New Lead',
                subtitle: 'Manually add and allot or broadcast a new lead',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'New',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddLeadScreen(
                        currentUser: user,
                        onLeadAdded: (newLead) {
                          onLeadsUpdated([newLead, ...leads]);
                        },
                      ),
                    ),
                  );
                },
              ),

            // Administrator-only Lead Allotment
            if (user.isAdmin)
              _MenuItem(
                icon: Icons.assignment_ind_outlined,
                title: 'Lead Allotment',
                subtitle: 'Allot unallocated leads to sales executives',
                trailing: _unassignedCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          '$_unassignedCount unassigned',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      )
                    : null,
                onTap: () {
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

            // Administrator-only Campaigns
            if (user.isAdmin)
              _MenuItem(
                icon: Icons.campaign_outlined,
                title: 'Campaigns',
                subtitle: 'Manage your advertising campaigns',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CampaignsScreen(),
                    ),
                  );
                },
              ),

            // Administrator-only Team
            if (user.isAdmin)
              _MenuItem(
                icon: Icons.people_outline,
                title: 'Team',
                subtitle: 'Manage team members and assignments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeamScreen(),
                    ),
                  );
                },
              ),

            // Tasks available for everyone
            _MenuItem(
              icon: Icons.task_alt_outlined,
              title: 'Tasks',
              subtitle: 'Manage your CRM tasks',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TasksScreen(),
                  ),
                );
              },
            ),

            // Notifications Center
            _MenuItem(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications & Alerts',
              subtitle: 'New lead alerts for Admin & Sales',
              trailing: _connectedBadge('Live'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      leads: leads,
                      onLeadsUpdated: onLeadsUpdated,
                    ),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 18),

          _sectionTitle('Integrations'),

          _menuCard([
            _MenuItem(
              icon: Icons.facebook,
              title: 'Meta Account Setup',
              subtitle: 'Connect Page, Ad Account & Leads Form',
              trailing: _connectedBadge('Setup'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MetaSetupScreen(),
                  ),
                );
              },
            ),
            _MenuItem(
              icon: Icons.hub_outlined,
              title: 'Integrations Hub',
              subtitle: 'Meta Ads, Firebase RTDB & Webhooks',
              trailing: _connectedBadge('Active'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IntegrationsScreen(),
                  ),
                );
              },
            ),
            _MenuItem(
              icon: Icons.chat_outlined,
              title: 'WhatsApp',
              subtitle: 'Connect WhatsApp Business',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'Connect your email service',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 18),

          _sectionTitle('Account'),

          _menuCard([
            _MenuItem(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Manage your account details',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.security_outlined,
              title: 'Security',
              subtitle: 'Password and security settings',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Application preferences',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () {
              _showLogoutDialog(context);
            },
            icon: const Icon(
              Icons.logout_outlined,
              color: Color(0xFFDC2626),
            ),
            label: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              side: const BorderSide(
                color: Color(0xFFFECACA),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(user: user),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: user.isAdmin
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFDCFCE7),
              child: Text(
                user.initial,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: user.isAdmin
                      ? AppTheme.primary
                      : const Color(0xFF16A34A),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: user.isAdmin
                                ? AppTheme.primary
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          user.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _menuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;

          return Column(
            children: [
              ListTile(
                leading: Icon(
                  item.icon,
                  color: AppTheme.primary,
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: item.trailing ??
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                onTap: item.onTap,
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  color: AppTheme.border,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _connectedBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from Eligible CRM?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                minimumSize: const Size(90, 40),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });
}