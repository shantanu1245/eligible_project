import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';
import '../screens/lead_detail.dart';
import '../widgets/skeleton_loading.dart';

class FollowupsScreen extends StatefulWidget {
  final List<Lead> leads;
  final bool isLoading;
  final Function(Lead)? onLeadUpdated;

  const FollowupsScreen({
    super.key,
    this.leads = const [],
    this.isLoading = false,
    this.onLeadUpdated,
  });

  @override
  State<FollowupsScreen> createState() => _FollowupsScreenState();
}

class _FollowupsScreenState extends State<FollowupsScreen> {
  late List<Map<String, dynamic>> followups;

  @override
  void initState() {
    super.initState();
    _buildFollowupsFromLeads();
  }

  @override
  void didUpdateWidget(covariant FollowupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads != widget.leads) {
      _buildFollowupsFromLeads();
    }
  }

  void _buildFollowupsFromLeads() {
    // Generate follow-ups dynamically from real database leads
    final List<Map<String, dynamic>> items = [];

    for (int i = 0; i < widget.leads.length; i++) {
      final lead = widget.leads[i];
      // Leads with status newLead, contacted, or qualified need follow-ups
      if (lead.status == LeadStatus.converted || lead.status == LeadStatus.lost) {
        continue;
      }

      String taskText;
      String type;
      String dateCategory;
      String timeStr;

      if (lead.status == LeadStatus.newLead) {
        taskText = lead.requiredLoan != null && lead.requiredLoan! > 0
            ? 'Initial consultation for ₹${(lead.requiredLoan! / 100000).toStringAsFixed(1)}L ${lead.loanType ?? "loan"}'
            : 'Initial inquiry verification call';
        type = 'Call';
        dateCategory = (i % 2 == 0) ? 'Today' : 'Upcoming';
        timeStr = '10:${30 + (i * 10) % 30} AM';
      } else if (lead.status == LeadStatus.contacted) {
        taskText = lead.propertyCost != null && lead.propertyCost! > 0
            ? 'Document collection for property assessment (${lead.city ?? "Pune"})'
            : 'Collect income and CIBIL verification documents';
        type = 'Task';
        dateCategory = (i % 3 == 0) ? 'Today' : 'Upcoming';
        timeStr = '02:${15 + (i * 15) % 40} PM';
      } else {
        taskText = 'Sanction letter & agreement discussion';
        type = 'Meeting';
        dateCategory = 'Upcoming';
        timeStr = '04:00 PM';
      }

      items.add({
        'leadId': lead.id,
        'lead': lead,
        'name': lead.name,
        'phone': lead.phone,
        'task': taskText,
        'time': timeStr,
        'date': dateCategory,
        'type': type,
      });
    }

    setState(() {
      followups = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayItems = followups.where((item) => item['date'] == 'Today').toList();
    final upcomingItems = followups.where((item) => item['date'] == 'Upcoming').toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-ups',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              '${followups.length} scheduled client follow-ups',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: widget.isLoading
          ? const FollowupsScreenSkeleton()
          : followups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No active follow-ups needed',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All ${widget.leads.length} database leads are up to date',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                _buildSummary(todayItems.length, upcomingItems.length),
                const SizedBox(height: 22),
                if (todayItems.isNotEmpty) ...[
                  const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...todayItems.map((item) => _followupCard(item)),
                  const SizedBox(height: 20),
                ],
                if (upcomingItems.isNotEmpty) ...[
                  const Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...upcomingItems.map((item) => _followupCard(item)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddFollowupDialog(context);
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Follow-up',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(int todayCount, int upcomingCount) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Today',
            '$todayCount',
            Icons.today_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Upcoming',
            '$upcomingCount',
            Icons.event_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Total Active',
            '${todayCount + upcomingCount}',
            Icons.task_alt_outlined,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
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
    );
  }

  Widget _followupCard(
    Map<String, dynamic> item,
  ) {
    final Lead? lead = item['lead'] is Lead ? item['lead'] as Lead : null;

    return Dismissible(
      key: ValueKey(
        '${item['name']}-${item['time']}-${item['leadId'] ?? ""}',
      ),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(
          right: 20,
        ),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item['name']} follow-up completed',
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: lead != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeadDetailsScreen(
                        lead: lead,
                        onLeadUpdated: widget.onLeadUpdated,
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
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
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.phone_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['task']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item['time']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['type']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFollowupDialog(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Follow-up',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 20),

              const TextField(
                decoration: InputDecoration(
                  labelText: 'Lead',
                  hintText: 'Select lead',
                ),
              ),

              const SizedBox(height: 14),

              const TextField(
                decoration: InputDecoration(
                  labelText: 'Task',
                  hintText: 'What needs to be done?',
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration:
                          const InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration:
                          const InputDecoration(
                        labelText: 'Time',
                        suffixIcon: Icon(
                          Icons.access_time_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Create Follow-up',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}