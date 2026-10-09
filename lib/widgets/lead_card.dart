import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';
import '../screens/lead_detail.dart';

import '../models/user.dart';

class LeadCard extends StatelessWidget {
  final Lead lead;
  final bool compact;
  final UserModel? currentUser;
  final Function(Lead)? onLeadUpdated;

  const LeadCard({
    super.key,
    required this.lead,
    this.compact = false,
    this.currentUser,
    this.onLeadUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeadDetailsScreen(
              lead: lead,
              currentUser: currentUser,
              onLeadUpdated: onLeadUpdated,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(
          compact ? 14 : 17,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: compact ? 21 : 24,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    lead.name.trim().substring(0, 1).toUpperCase(),
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
                        lead.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        lead.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (lead.requiredLoan != null && lead.requiredLoan! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (lead.loanType ?? 'Loan').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${lead.requiredLoan! >= 100000 ? "${(lead.requiredLoan! / 100000).toStringAsFixed(1)}L" : lead.requiredLoan!.toInt().toString()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            if (lead.city != null && lead.city!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${lead.city}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                _StatusBadge(
                  status: lead.status,
                ),
              ],
            ),

            if (!compact) ...[
              const SizedBox(height: 15),

              const Divider(
                color: AppTheme.border,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _Info(
                      label: lead.salary != null ? 'Monthly Income' : 'Source',
                      value: lead.salary != null ? '₹${lead.salary!.toInt()}' : lead.source,
                      icon: lead.salary != null ? Icons.currency_rupee : Icons.campaign_outlined,
                    ),
                  ),

                  Expanded(
                    child: _Info(
                      label: lead.cibil != null && lead.cibil! > 0 ? 'CIBIL Score' : 'Campaign',
                      value: lead.cibil != null && lead.cibil! > 0 ? '${lead.cibil}' : lead.campaign,
                      icon: lead.cibil != null && lead.cibil! > 0 ? Icons.speed : Icons.ads_click_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Icon(
                    lead.assignedTo.trim().isEmpty
                        ? Icons.warning_amber_rounded
                        : Icons.assignment_ind_outlined,
                    size: 14,
                    color: lead.assignedTo.trim().isEmpty
                        ? const Color(0xFFDC2626)
                        : AppTheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    lead.assignedTo.trim().isEmpty
                        ? 'Unassigned Lead'
                        : 'Assigned to: ${lead.assignedTo}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: lead.assignedTo.trim().isEmpty
                          ? const Color(0xFFDC2626)
                          : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Info({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: AppTheme.textSecondary,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LeadStatus status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final data = _statusData(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: data.foreground,
        ),
      ),
    );
  }

  _StatusStyle _statusData(
    LeadStatus status,
  ) {
    switch (status) {
      case LeadStatus.newLead:
        return const _StatusStyle(
          'New',
          Color(0xFFEFF6FF),
          Color(0xFF2563EB),
        );

      case LeadStatus.contacted:
        return const _StatusStyle(
          'Contacted',
          Color(0xFFFFF7ED),
          Color(0xFFEA580C),
        );

      case LeadStatus.qualified:
        return const _StatusStyle(
          'Qualified',
          Color(0xFFF0FDF4),
          Color(0xFF16A34A),
        );

      case LeadStatus.converted:
        return const _StatusStyle(
          'Converted',
          Color(0xFFF0FDFA),
          Color(0xFF0F766E),
        );

      case LeadStatus.lost:
        return const _StatusStyle(
          'Lost',
          Color(0xFFFEF2F2),
          Color(0xFFDC2626),
        );
    }
  }
}

class _StatusStyle {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusStyle(
    this.label,
    this.background,
    this.foreground,
  );
}
