import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
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
  late String currentNote;
  bool _isAddingNote = false;

  final TextEditingController noteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.lead.status;
    currentNote = widget.lead.note;
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
        return 'In Process';
      case LeadStatus.lost:
        return 'Rejected';
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
        title: Text(
          lead.name.isNotEmpty ? lead.name : 'Lead Details',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
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

          if (widget.lead.displayMessage.isNotEmpty) ...[
            _buildCustomerInquiryCard(widget.lead),
            const SizedBox(height: 16),
          ],

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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            lead.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),

          if (lead.email.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              lead.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
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
                fontSize: 12.5,
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
                final knownExecNames = UserModel.teamMembers.map((e) => e.name).toSet();
                final items = <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Unassigned / Available for Claim'),
                  ),
                  ...UserModel.teamMembers.map((exec) {
                    return DropdownMenuItem(
                      value: exec.name,
                      child: Text('${exec.name} (${exec.roleDisplayName})'),
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
                  value: selectedDropdownValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Allot to Team Member',
                    prefixIcon: Icon(Icons.assignment_ind_outlined),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  items: items,
                  onChanged: (newAssignee) {
                    if (newAssignee != null && newAssignee != currentAssignedTo) {
                      setState(() {
                        currentAssignedTo = newAssignee;
                      });
                      final updatedLead =
                          widget.lead.copyWith(assignedTo: newAssignee);
                      widget.onLeadUpdated?.call(updatedLead);

                      if (newAssignee.isNotEmpty) {
                        BackendService().allotLead(
                          widget.lead.id,
                          assignedTo: newAssignee,
                          allottedBy: widget.currentUser?.name ?? 'Admin',
                        );
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newAssignee.isEmpty
                                ? 'Lead marked as Unassigned'
                                : 'Lead allotted to $newAssignee (Notification sent to their devices)',
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
        value: selectedStatus,
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
        onChanged: (newStatus) {
          if (newStatus == null || newStatus == selectedStatus) return;

          final oldStatus = selectedStatus;
          setState(() {
            selectedStatus = newStatus;
          });

          final updatedLead = widget.lead.copyWith(status: newStatus);
          widget.onLeadUpdated?.call(updatedLead);

          final agentName = widget.currentUser?.name ?? 'Sales Agent';
          final oldName = statusName(oldStatus);
          final newName = statusName(newStatus);

          // Update backend and trigger real-time notification to Admin
          BackendService().updateLeadStatus(
            leadId: widget.lead.id,
            status: newStatus.name,
            previousStatus: oldStatus.name,
            updatedBy: agentName,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status changed from "$oldName" to "$newName". Admin notified.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerInquiryCard(Lead lead) {
    final isWhatsApp = lead.source.toLowerCase().contains('whatsapp') ||
        lead.campaign.toLowerCase().contains('whatsapp') ||
        lead.campaign.toLowerCase().contains("what's app");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhatsApp ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWhatsApp ? const Color(0xFF86EFAC) : AppTheme.border,
          width: isWhatsApp ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isWhatsApp ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isWhatsApp ? Icons.chat_rounded : Icons.mark_chat_read_outlined,
                  size: 18,
                  color: isWhatsApp ? const Color(0xFF16A34A) : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWhatsApp ? 'Incoming WhatsApp Message' : 'Customer Inquiry Message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isWhatsApp ? const Color(0xFF166534) : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Received from ${lead.phone}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isWhatsApp ? const Color(0xFF15803D) : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isWhatsApp ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              lead.displayMessage,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                height: 1.45,
              ),
            ),
          ),
          if (isWhatsApp) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openWhatsApp(lead.phone),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text(
                  'Open WhatsApp Chat & Reply',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
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

  Future<void> _addNote() async {
    final text = noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a note before saving'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAddingNote = true);

    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final timeStr = '${now.day} ${months[now.month - 1]}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final author = widget.currentUser?.name ?? 'Admin';
    final newEntry = '[$timeStr • $author]\n$text';

    final updatedNote = currentNote.trim().isEmpty ? newEntry : '$newEntry\n\n$currentNote';

    try {
      await BackendService().addLeadNote(
        leadId: widget.lead.id,
        note: updatedNote,
        author: author,
      );

      final updatedLead = widget.lead.copyWith(note: updatedNote);
      widget.onLeadUpdated?.call(updatedLead);

      if (mounted) {
        setState(() {
          currentNote = updatedNote;
          _isAddingNote = false;
          noteController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Note added successfully'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingNote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to add note: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildNotesCard() {
    final noteBlocks = currentNote.trim().isNotEmpty
        ? currentNote.trim().split(RegExp(r'\n{2,}'))
        : <String>[];

    return _sectionCard(
      title: 'Notes & Remarks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing notes list
          if (noteBlocks.isNotEmpty) ...[
            ...noteBlocks.map((block) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 10),
                      child: Icon(Icons.sticky_note_2_outlined, size: 18, color: AppTheme.primary),
                    ),
                    Expanded(
                      child: SelectableText(
                        block,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
          ] else ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No notes recorded yet for this lead.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Add note input
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write a note about this lead...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAddingNote ? null : _addNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isAddingNote
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_comment_rounded, size: 18),
              label: Text(
                _isAddingNote ? 'Saving Note...' : 'Add Note',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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