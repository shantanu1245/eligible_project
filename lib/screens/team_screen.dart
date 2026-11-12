import '../widgets/admin_guard.dart';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'add_agent_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final BackendService _backend = BackendService();
  final List<Map<String, String>> _members = [
    {
      'name': 'Admin',
      'email': 'admin@theligible.in',
      'role': 'Administrator',
      'initial': 'A',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (AdminGuard.isCurrentAdmin) {
      _loadTeam();
    }
  }

  Future<void> _loadTeam() async {
    final raw = await _backend.getTeam();
    if (mounted && raw.isNotEmpty) {
      setState(() {
        _members.clear();
        for (final item in raw) {
          _members.add({
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'email': item['email']?.toString() ?? '',
            'password': item['password']?.toString() ?? '',
            'role': item['role']?.toString() ?? 'Sales Executive',
            'initial': item['initial']?.toString() ?? (item['name'] != null && item['name'].toString().isNotEmpty ? item['name'][0].toUpperCase() : 'U'),
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      title: 'Team Management Restricted',
      message: 'Managing sales executives and team members is restricted strictly to Administrators.',
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Team',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAgentScreen,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          100,
        ),
        children: [
          _buildTeamSummary(),

          const SizedBox(height: 20),

          const Text(
            'Team Members',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          ..._members.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final member = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberCard(
                  member: member,
                  onEdit: () => _showEditMemberDialog(index),
                  onDelete: index == 0
                      ? null
                      : () {
                          final memberId = member['id'] ?? member['name'] ?? '';
                          if (memberId.isNotEmpty) {
                            _backend.deleteTeamMember(memberId);
                          }
                          setState(() {
                            _members.removeAt(index);
                          });
                        },
                ),
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTeamSummary() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Members',
            value: '${_members.length}',
            icon: Icons.people_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Executives',
            value: '${_members.where(
              (m) => m['role'] == 'Sales Executive',
            ).length}',
            icon: Icons.support_agent_outlined,
          ),
        ),
      ],
    );
  }

  Future<void> _openAddAgentScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAgentScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _members.add({
          'id': result['id']?.toString() ?? '',
          'name': result['name']?.toString() ?? '',
          'email': result['email']?.toString() ?? '',
          'password': result['password']?.toString() ?? '',
          'role': result['role']?.toString() ?? 'Sales Executive',
          'initial': result['initial']?.toString() ??
              (result['name'] != null && result['name'].toString().isNotEmpty
                  ? result['name'][0].toUpperCase()
                  : 'U'),
        });
      });
      _loadTeam();
    }
  }

  void _showEditMemberDialog(int index) {
    final member = _members[index];
    final nameController = TextEditingController(text: member['name'] ?? '');
    final emailController = TextEditingController(text: member['email'] ?? '');
    final passwordController = TextEditingController(text: member['password'] ?? '');

    String selectedRole = member['role'] ?? 'Sales Executive';
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Edit Team Member',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address / Login ID *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Login Password',
                        hintText: 'Enter new password or keep existing',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText: 'Update login password for agent',
                        helperMaxLines: 1,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Administrator',
                          child: Text('Administrator'),
                        ),
                        DropdownMenuItem(
                          value: 'Sales Executive',
                          child: Text('Sales Executive'),
                        ),
                        DropdownMenuItem(
                          value: 'Manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'Viewer',
                          child: Text('Viewer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();
                    if (name.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Full name and email are required.'),
                          backgroundColor: Color(0xFFDC2626),
                        ),
                      );
                      return;
                    }

                    final memberId = member['id'] ?? member['name'] ?? '';
                    final updated = {
                      'name': name,
                      'email': email,
                      if (password.isNotEmpty) 'password': password,
                      'role': selectedRole,
                      'initial': name.substring(0, 1).toUpperCase(),
                    };

                    setState(() {
                      _members[index] = {...member, ...updated};
                    });

                    if (memberId.isNotEmpty) {
                      _backend.updateTeamMember(memberId, updated);
                    }

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated $name successfully!'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, String> member;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            radius: 23,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              member['initial'] ?? '?',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  member['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      member['role'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (member['password'] != null && member['password']!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key_rounded, size: 10, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              member['password']!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit' && onEdit != null) {
                onEdit!();
              } else if (value == 'delete' && onDelete != null) {
                onDelete!();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Member'),
              ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove Member'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}