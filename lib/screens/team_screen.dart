import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final List<Map<String, String>> _members = [
    {
      'name': 'Shantanu',
      'email': 'admin@leadflow.com',
      'role': 'Administrator',
      'initial': 'S',
    },
    {
      'name': 'Amit Patil',
      'email': 'amit@leadflow.com',
      'role': 'Sales Executive',
      'initial': 'A',
    },
    {
      'name': 'Priya Shah',
      'email': 'priya@leadflow.com',
      'role': 'Sales Executive',
      'initial': 'P',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        onPressed: _showAddMemberDialog,
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
                  onDelete: index == 0
                      ? null
                      : () {
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

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    String selectedRole = 'Sales Executive';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Team Member',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
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
                    if (nameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty) {
                      return;
                    }

                    final name = nameController.text.trim();

                    setState(() {
                      _members.add({
                        'name': name,
                        'email': emailController.text.trim(),
                        'role': selectedRole,
                        'initial': name.substring(0, 1).toUpperCase(),
                      });
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add Member'),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, String> member;
  final VoidCallback? onDelete;

  const _MemberCard({
    required this.member,
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
                Text(
                  member['role'] ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete' && onDelete != null) {
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