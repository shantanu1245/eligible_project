import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailsScreen extends StatefulWidget {
  final Lead lead;
  final UserModel? currentUser;
  final Function(Lead)? onLeadUpdated;

  const LeadDetailsScreen({
    super.key,
    required this.lead,
    this.currentUser,
    this.onLeadUpdated,
  });

  @override
  State<LeadDetailsScreen> createState() =>
      _LeadDetailsScreenState();
}

class _LeadDetailsScreenState
    extends State<LeadDetailsScreen> {
  late LeadStatus selectedStatus;
  late String currentAssignedTo;

  final TextEditingController noteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.lead.status;
    final initialAssigned = widget.lead.assignedTo.trim();
    if (initialAssigned.isEmpty ||
        initialAssigned.toLowerCase() == 'unassigned' ||
        initialAssigned.toLowerCase() == 'available for claim') {
      currentAssignedTo = '';
    } else {
      currentAssignedTo = initialAssigned;
    }
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

          _buildAssignmentCard(),

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
    final lead = widget.lead;
    
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.call_outlined,
            label: 'Call',
            onTap: () => _makePhoneCall(lead.phone),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            onTap: () => _openWhatsApp(lead.phone),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.email_outlined,
            label: 'Email',
            onTap: () => _sendEmail(lead.email),
          ),
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      _showError('Could not launch phone dialer');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final Uri whatsappUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanPhone,
    );
    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Could not open WhatsApp');
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) {
      _showError('No email available');
      return;
    }
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      await launchUrl(emailUri);
    } catch (e) {
      _showError('Could not open email client');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    return Column(
      children: [
        if (lead.requiredLoan != null && lead.requiredLoan! > 0) ...[
          _buildLoanDetailsCard(lead),
          const SizedBox(height: 16),
        ],
        _sectionCard(
          title: 'Lead Information',
          child: Column(
            children: [
              _infoRow(
                Icons.phone_outlined,
                'Phone',
                lead.phone,
              ),
              if (lead.email.isNotEmpty)
                _infoRow(
                  Icons.email_outlined,
                  'Email',
                  lead.email,
                ),
              if (lead.city != null && lead.city!.isNotEmpty)
                _infoRow(
                  Icons.location_city_outlined,
                  'City & PIN',
                  '${lead.city}${lead.pincode != null ? " - ${lead.pincode!}" : ""}',
                ),
              _infoRow(
                Icons.campaign_outlined,
                'Source',
                lead.source,
              ),
              _infoRow(
                Icons.ads_click_outlined,
                'Campaign / Enquiry',
                lead.campaign,
              ),
              _infoRow(
                Icons.person_outline,
                'Assigned To',
                lead.assignedTo.isEmpty ? 'Unassigned' : lead.assignedTo,
              ),
              _infoRow(
                Icons.tag_outlined,
                'Lead ID',
                lead.id,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanDetailsCard(Lead lead) {
    return _sectionCard(
      title: 'Loan Eligibility & Financial Profile',
      child: Column(
        children: [
          _infoRow(
            Icons.account_balance_outlined,
            'Loan Category',
            (lead.loanType ?? 'Salary').toUpperCase(),
          ),
          _infoRow(
            Icons.currency_rupee,
            'Required Loan Amount',
            '₹${lead.requiredLoan!.toInt().toString().replaceAllMapped(RegExp(r"(\d)(?=(\d\d)+\d$)"), (m) => "${m[1]},")}',
          ),
          if (lead.estimatedLow != null && lead.estimatedHigh != null && lead.estimatedHigh! > 0)
            _infoRow(
              Icons.trending_up,
              'Eligible Range',
              '₹${(lead.estimatedLow! / 100000).toStringAsFixed(1)}L - ₹${(lead.estimatedHigh! / 100000).toStringAsFixed(1)}L',
            ),
          if (lead.salary != null && lead.salary! > 0)
            _infoRow(
              Icons.payments_outlined,
              lead.loanType == 'business' ? 'Annual Turnover' : 'Monthly Income',
              '₹${lead.salary!.toInt().toString().replaceAllMapped(RegExp(r"(\d)(?=(\d\d)+\d$)"), (m) => "${m[1]},")}',
            ),
          if (lead.emi != null && lead.emi! > 0)
            _infoRow(
              Icons.credit_card_outlined,
              'Existing EMI',
              '₹${lead.emi!.toInt()}/mo',
            ),
          if (lead.cibil != null && lead.cibil! > 0)
            _infoRow(
              Icons.speed_outlined,
              'CIBIL Score',
              '${lead.cibil}',
            ),
          if (lead.job != null && lead.job!.isNotEmpty)
            _infoRow(
              Icons.work_outline,
              'Job / Occupation',
              lead.job!,
            ),
          if (lead.propertyCost != null && lead.propertyCost! > 0)
            _infoRow(
              Icons.home_work_outlined,
              'Property Value',
              '₹${(lead.propertyCost! / 100000).toStringAsFixed(1)} Lakhs',
            ),
          if (lead.propertyType != null && lead.propertyType!.isNotEmpty)
            _infoRow(
              Icons.home_outlined,
              'Property Type',
              lead.propertyType!,
            ),
          if (lead.businessType != null && lead.businessType!.isNotEmpty)
            _infoRow(
              Icons.business_outlined,
              'Business Vintage / Type',
              '${lead.businessVintage ?? ""} • ${lead.businessType!}',
            ),
          if (lead.gstRegistered != null && lead.gstRegistered!.isNotEmpty)
            _infoRow(
              Icons.receipt_long_outlined,
              'GST / ITR',
              'GST: ${lead.gstRegistered} | ${lead.itrVintage ?? ""}',
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

  Widget _buildAssignmentCard() {
    final isUnassigned = currentAssignedTo.trim().isEmpty;
    final isAdmin = widget.currentUser?.isAdmin ?? true;

    return _sectionCard(
      title: 'Lead Allotment & Assignee',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isUnassigned
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFEFF6FF),
                child: Icon(
                  isUnassigned
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                  size: 20,
                  color: isUnassigned
                      ? const Color(0xFFDC2626)
                      : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnassigned
                          ? 'Unassigned Lead'
                          : 'Assigned to: $currentAssignedTo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isUnassigned
                            ? const Color(0xFFDC2626)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnassigned
                          ? 'This lead has not yet been allotted to an executive.'
                          : 'Sales Executive managing this client.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                // Determine valid items
                final knownExecNames = UserModel.salesExecutives.map((e) => e.name).toSet();
                final items = <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Unassigned / Available for Claim'),
                  ),
                  ...UserModel.salesExecutives.map((exec) {
                    return DropdownMenuItem(
                      value: exec.name,
                      child: Text('${exec.name} (Sales Executive)'),
                    );
                  }),
                ];

                // If current assignee is set to a custom or unknown name, add it dynamically so dropdown never throws
                if (currentAssignedTo.isNotEmpty && !knownExecNames.contains(currentAssignedTo)) {
                  items.add(
                    DropdownMenuItem(
                      value: currentAssignedTo,
                      child: Text('$currentAssignedTo (Assigned)'),
                    ),
                  );
                }

                final selectedDropdownValue = isUnassigned
                    ? ''
                    : (items.any((item) => item.value == currentAssignedTo) ? currentAssignedTo : '');

                return DropdownButtonFormField<String>(
                  initialValue: selectedDropdownValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Allot to Sales Executive',
                    prefixIcon: Icon(Icons.assignment_ind_outlined),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  items: items,
                  onChanged: (newAssignee) {
                    if (newAssignee != null) {
                      setState(() {
                        currentAssignedTo = newAssignee;
                      });
                      final updatedLead =
                          widget.lead.copyWith(assignedTo: newAssignee);
                      widget.onLeadUpdated?.call(updatedLead);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newAssignee.isEmpty
                                ? 'Lead marked as Unassigned'
                                : 'Lead allotted to $newAssignee',
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _sectionCard(
      title: 'Lead Status',
      child: DropdownButtonFormField<LeadStatus>(
        initialValue: selectedStatus,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          isDense: true,
        ),
        items: LeadStatus.values.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              statusName(status),
              overflow: TextOverflow.ellipsis,
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