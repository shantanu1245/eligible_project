import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Follow up with Rahul Patil',
      'description': 'Call the lead regarding property enquiry.',
      'assignee': 'Amit Patil',
      'priority': 'High',
      'status': 'Pending',
      'dueDate': 'Today',
    },
    {
      'title': 'Contact new Meta leads',
      'description': 'Call all new leads received from Meta Ads.',
      'assignee': 'Priya Shah',
      'priority': 'Medium',
      'status': 'Pending',
      'dueDate': 'Tomorrow',
    },
    {
      'title': 'Update campaign lead status',
      'description': 'Review and update qualified leads.',
      'assignee': 'Amit Patil',
      'priority': 'Low',
      'status': 'Completed',
      'dueDate': 'Yesterday',
    },
  ];

  final List<String> _teamMembers = [
    'Amit Patil',
    'Priya Shah',
    'Shantanu',
  ];

  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _tasks.where((task) {
      if (_filter == 'All') {
        return true;
      }

      if (_filter == 'Pending') {
        return task['status'] == 'Pending';
      }

      if (_filter == 'Completed') {
        return task['status'] == 'Completed';
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          100,
        ),
        children: [
          _buildSummary(),

          const SizedBox(height: 18),

          _buildFilters(),

          const SizedBox(height: 14),

          if (filteredTasks.isEmpty)
            _buildEmptyState()
          else
            ...filteredTasks.asMap().entries.map(
              (entry) {
                final index = _tasks.indexOf(entry.value);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(
                    task: entry.value,
                    onStatusChanged: () {
                      setState(() {
                        _tasks[index]['status'] =
                            _tasks[index]['status'] == 'Completed'
                                ? 'Pending'
                                : 'Completed';
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

  Widget _buildSummary() {
    final pending = _tasks.where(
      (task) => task['status'] == 'Pending',
    ).length;

    final completed = _tasks.where(
      (task) => task['status'] == 'Completed',
    ).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total',
            value: '${_tasks.length}',
            icon: Icons.task_alt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Pending',
            value: '$pending',
            icon: Icons.pending_actions_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Done',
            value: '$completed',
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          _filterButton('All'),
          _filterButton('Pending'),
          _filterButton('Completed'),
        ],
      ),
    );
  }

  Widget _filterButton(String value) {
    final selected = _filter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 45,
            color: AppTheme.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'No tasks found',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Create a task to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    String selectedMember = _teamMembers.first;
    String selectedPriority = 'Medium';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Create Task',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        prefixIcon: Icon(
                          Icons.task_alt_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(
                          Icons.description_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedMember,
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                      ),
                      items: _teamMembers.map(
                        (member) {
                          return DropdownMenuItem(
                            value: member,
                            child: Text(member),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedMember = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(
                          Icons.flag_outlined,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Low',
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'High',
                          child: Text('High'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedPriority = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: DateTime.now(),
                        );

                        if (date != null) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      label: const Text('Select Due Date'),
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
                    if (titleController.text.trim().isEmpty) {
                      return;
                    }

                    setState(() {
                      _tasks.insert(
                        0,
                        {
                          'title': titleController.text.trim(),
                          'description':
                              descriptionController.text.trim(),
                          'assignee': selectedMember,
                          'priority': selectedPriority,
                          'status': 'Pending',
                          'dueDate': 'Today',
                        },
                      );
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Create Task'),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onStatusChanged;

  const _TaskCard({
    required this.task,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = task['status'] == 'Completed';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onStatusChanged,
            child: Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? const Color(0xFF16A34A)
                    : Colors.transparent,
                border: Border.all(
                  color: completed
                      ? const Color(0xFF16A34A)
                      : AppTheme.textSecondary,
                  width: 1.5,
                ),
              ),
              child: completed
                  ? const Icon(
                      Icons.check,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    decoration: completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: completed
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  task['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 9),

                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task['assignee'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task['dueDate'],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _PriorityBadge(
            priority: task['priority'],
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (priority) {
      case 'High':
        background = const Color(0xFFFEF2F2);
        foreground = const Color(0xFFDC2626);
        break;

      case 'Low':
        background = const Color(0xFFF0FDF4);
        foreground = const Color(0xFF16A34A);
        break;

      default:
        background = const Color(0xFFFFF7ED);
        foreground = const Color(0xFFEA580C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}