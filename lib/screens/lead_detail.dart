import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';

class LeadDetailsScreen extends StatefulWidget {
  final Lead lead;

  const LeadDetailsScreen({
    super.key,
    required this.lead,
  });

  @override
  State<LeadDetailsScreen> createState() =>
      _LeadDetailsScreenState();
}

class _LeadDetailsScreenState
    extends State<LeadDetailsScreen> {
  late LeadStatus selectedStatus;

  final TextEditingController noteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.lead.status;
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  String statusName(LeadStatus status) {
    switch (status) {
      case LeadStatus.newLead:
        return 'New';
      case LeadStatus.contacted:
        return 'Contacted';
      case LeadStatus.qualified:
        return 'Qualified';
      case LeadStatus.converted:
        return 'Converted';
      case LeadStatus.lost:
        return 'Lost';
    }
  }

  Color statusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.newLead:
        return const Color(0xFF2563EB);
      case LeadStatus.contacted:
        return const Color(0xFFEA580C);
      case LeadStatus.qualified:
        return const Color(0xFF16A34A);
      case LeadStatus.converted:
        return const Color(0xFF0F766E);
      case LeadStatus.lost:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;

    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        title: const Text(
          'Lead Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert_rounded,
            ),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          30,
        ),
        children: [
          _buildProfileCard(lead),

          const SizedBox(height: 16),

          _buildQuickActions(),

          const SizedBox(height: 16),

          _buildInformationCard(lead),

          const SizedBox(height: 16),

          _buildStatusCard(),

          const SizedBox(height: 16),

          _buildActivityCard(),

          const SizedBox(height: 16),

          _buildNotesCard(),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Lead lead) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              lead.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            lead.name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            lead.email,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor(selectedStatus)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusName(selectedStatus),
              style: TextStyle(
                color: statusColor(selectedStatus),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.call_outlined,
            label: 'Call',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.email_outlined,
            label: 'Email',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppTheme.primary,
                size: 21,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard(Lead lead) {
    return _sectionCard(
      title: 'Lead Information',
      child: Column(
        children: [
          _infoRow(
            Icons.phone_outlined,
            'Phone',
            lead.phone,
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            lead.email,
          ),
          _infoRow(
            Icons.campaign_outlined,
            'Source',
            lead.source,
          ),
          _infoRow(
            Icons.ads_click_outlined,
            'Campaign',
            lead.campaign,
          ),
          _infoRow(
            Icons.person_outline,
            'Assigned To',
            lead.assignedTo,
          ),
          _infoRow(
            Icons.tag_outlined,
            'Lead ID',
            lead.id,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.border,
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _sectionCard(
      title: 'Lead Status',
      child: DropdownButtonFormField<LeadStatus>(
        initialValue: selectedStatus,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
        items: LeadStatus.values.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              statusName(status),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            selectedStatus = value;
          });
        },
      ),
    );
  }

  Widget _buildActivityCard() {
    return _sectionCard(
      title: 'Activity Timeline',
      child: Column(
        children: [
          _timelineItem(
            icon: Icons.person_add_outlined,
            title: 'Lead created',
            subtitle: 'Received from Facebook',
            time: 'Today, 8:32 PM',
          ),
          _timelineItem(
            icon: Icons.person_outline,
            title: 'Lead assigned',
            subtitle: 'Assigned to Shantanu',
            time: 'Today, 8:45 PM',
          ),
          _timelineItem(
            icon: Icons.phone_outlined,
            title: 'Follow-up scheduled',
            subtitle: 'Call customer tomorrow',
            time: 'Today, 9:05 PM',
          ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
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

  Widget _buildNotesCard() {
    return _sectionCard(
      title: 'Notes',
      child: Column(
        children: [
          TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add a note about this lead...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Add Note',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}