import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'campaigns_screen.dart';
import 'team_screen.dart';
import 'tasks_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          30,
        ),
        children: [
          _buildProfile(),

          const SizedBox(height: 18),

          _sectionTitle('Workspace'),

          _menuCard([
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
          ]),

          const SizedBox(height: 18),

          _sectionTitle('Integrations'),

          _menuCard([
            _MenuItem(
              icon: Icons.facebook,
              title: 'Meta Ads',
              subtitle: 'Connect Facebook and Instagram',
              trailing: _connectedBadge(
                'Not connected',
              ),
              onTap: () {},
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
              subtitle: 'Manage your account',
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

          const SizedBox(height: 18),

          _sectionTitle('Data'),

          _menuCard([
            _MenuItem(
              icon: Icons.file_upload_outlined,
              title: 'Import Leads',
              subtitle: 'Import leads from CSV',
              onTap: () {},
            ),

            _MenuItem(
              icon: Icons.file_download_outlined,
              title: 'Export Leads',
              subtitle: 'Export your CRM data',
              onTap: () {},
            ),

            _MenuItem(
              icon: Icons.history_outlined,
              title: 'Activity Log',
              subtitle: 'View account activity',
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
              minimumSize: const Size(
                double.infinity,
                52,
              ),
              side: const BorderSide(
                color: Color(0xFFFECACA),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Center(
            child: Text(
              'LeadFlow CRM • Version 1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFDBEAFE),
            child: Text(
              'S',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shantanu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 9,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _menuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: List.generate(
          items.length,
          (index) {
            final item = items[index];

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 3,
                  ),

                  leading: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),

                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  subtitle: Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  trailing: item.trailing ??
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary,
                      ),

                  onTap: item.onTap,
                ),

                if (index != items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 70,
                    endIndent: 15,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _connectedBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  void _showLogoutDialog(
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            TextButton(
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
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                ),
              ),
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

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
}