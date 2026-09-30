import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class AddLeadScreen extends StatefulWidget {
  final UserModel currentUser;
  final Function(Lead)? onLeadAdded;

  const AddLeadScreen({
    super.key,
    required this.currentUser,
    this.onLeadAdded,
  });

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _campaignController = TextEditingController(text: 'General Campaign');
  final _noteController = TextEditingController();

  String _selectedSource = 'Meta Ads';
  LeadStatus _selectedStatus = LeadStatus.newLead;
  String _assignedTo = '';
  bool _isSubmitting = false;

  final List<String> _sources = [
    'Meta Ads',
    'Facebook',
    'Instagram',
    'Google Ads',
    'Website',
    'Referral',
    'Walk-in',
    'Direct',
  ];

  final List<Map<String, String>> _campaignPresets = [
    {'title': 'General Campaign', 'desc': 'All products'},
    {'title': 'Pune Doctors Drive', 'desc': 'Doctor loans'},
    {'title': 'Education Loan Promo', 'desc': 'Higher studies'},
    {'title': 'Personal Loan Drive', 'desc': 'Quick personal'},
  ];

  final List<UserModel> _executives = UserModel.salesExecutives;

  @override
  void initState() {
    super.initState();
    // If current user is a sales executive, default assign to themselves
    if (widget.currentUser.isSalesExecutive) {
      _assignedTo = widget.currentUser.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _campaignController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final campaign = _campaignController.text.trim();
      final note = _noteController.text.trim();
      final assigned = _assignedTo.trim();

      final res = await BackendService().createLead(
        name: name,
        phone: phone,
        email: email.isNotEmpty ? email : '$phone@lead.eligiblecrm.com',
        source: _selectedSource,
        campaign: campaign.isNotEmpty ? campaign : 'General Campaign',
        status: _selectedStatus.name,
        assignedTo: assigned,
        note: note,
        addedBy: widget.currentUser.name,
      );

      final createdMap = res['data'] ?? res;
      final leadId = createdMap['id']?.toString() ??
          'lead_${DateTime.now().millisecondsSinceEpoch}';

      final createdLead = Lead(
        id: leadId,
        name: name,
        phone: phone,
        email: email.isNotEmpty ? email : '$phone@lead.eligiblecrm.com',
        source: _selectedSource,
        campaign: campaign.isNotEmpty ? campaign : 'General Campaign',
        status: _selectedStatus,
        assignedTo: assigned,
        createdAt: DateTime.now(),
        note: note,
      );

      widget.onLeadAdded?.call(createdLead);

      if (mounted) {
        final notifMsg = assigned.isEmpty
            ? '📢 Broadcast alert sent to all executives & admins!'
            : '🎯 Targeted alert sent exclusively to $assigned!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF22C55E), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lead "$name" added successfully!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notifMsg,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.pop(context, createdLead);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add lead: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentUser.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Add New Lead',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Top notification explanation card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _assignedTo.isEmpty
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _assignedTo.isEmpty
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _assignedTo.isEmpty
                        ? Icons.campaign_rounded
                        : Icons.assignment_turned_in_rounded,
                    color: _assignedTo.isEmpty
                        ? AppTheme.primary
                        : const Color(0xFF16A34A),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assignedTo.isEmpty
                              ? 'Automatic Broadcast Notification'
                              : 'Targeted User Allotment Alert',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _assignedTo.isEmpty
                                ? AppTheme.primaryDark
                                : const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _assignedTo.isEmpty
                              ? 'Saving this lead as unassigned will trigger an instant notification to all sales agents and admins across every device they are logged in on.'
                              : 'This lead will be allotted directly to $_assignedTo. An instant alert will be sent only to their devices wherever they are logged in.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _assignedTo.isEmpty
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF166534),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section 1: Contact Information
            _buildSectionCard(
              title: 'Contact Details',
              icon: Icons.person_outline_rounded,
              children: [
                _buildLabel('Full Name *'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Dr. Rajesh Sharma',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the lead full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildLabel('Phone Number *'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'e.g. +91 98230 12345',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a contact phone number';
                    }
                    if (val.trim().length < 8) {
                      return 'Phone number must be at least 8 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildLabel('Email Address (Optional)'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'e.g. rajesh@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section 2: Lead Allotment / Assignment (if Admin)
            if (isAdmin)
              _buildSectionCard(
                title: 'Lead Allotment',
                icon: Icons.assignment_ind_outlined,
                children: [
                  _buildLabel('Assign Lead To'),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _assignedTo,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Row(
                              children: [
                                Icon(Icons.group_outlined,
                                    size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text(
                                  'Unassigned (Broadcast to All Executives)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._executives.map(
                            (e) => DropdownMenuItem(
                              value: e.name,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: const Color(0xFFDCFCE7),
                                    child: Text(
                                      e.initial,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${e.name} (${e.roleDisplayName})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _assignedTo = val ?? '';
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),

            if (isAdmin) const SizedBox(height: 16),

            // Section 3: Source & Campaign
            _buildSectionCard(
              title: 'Source & Campaign',
              icon: Icons.ads_click_rounded,
              children: [
                _buildLabel('Lead Source'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sources.map((src) {
                    final selected = _selectedSource == src;
                    return ChoiceChip(
                      label: Text(src),
                      selected: selected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedSource = src);
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                      selectedColor: AppTheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildLabel('Campaign Name'),
                TextFormField(
                  controller: _campaignController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. General Campaign',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                // Quick Campaign Presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _campaignPresets.map((preset) {
                    final isCurrent =
                        _campaignController.text == preset['title'];
                    return ActionChip(
                      label: Text(
                        preset['title']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      backgroundColor: isCurrent
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color:
                            isCurrent ? AppTheme.primary : Colors.transparent,
                      ),
                      onPressed: () {
                        setState(() {
                          _campaignController.text = preset['title']!;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section 4: Initial Status & Notes
            _buildSectionCard(
              title: 'Status & Requirement Notes',
              icon: Icons.notes_rounded,
              children: [
                _buildLabel('Initial Status'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('New Lead', LeadStatus.newLead),
                    _statusChip('Contacted', LeadStatus.contacted),
                    _statusChip('Qualified', LeadStatus.qualified),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Notes / Customer Requirements'),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Doctor in Pune looking for 25L business loan for new equipment.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitLead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Saving & Dispatching Alerts...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _assignedTo.isEmpty
                              ? 'Add Lead & Broadcast Alert'
                              : 'Add Lead & Allot to $_assignedTo',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppTheme.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _statusChip(String label, LeadStatus status) {
    final selected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _selectedStatus = status);
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.textSecondary,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppTheme.primary : AppTheme.border,
      ),
    );
  }
}
