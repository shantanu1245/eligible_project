import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final BackendService _backend = BackendService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);
    final data = await _backend.getCampaigns();
    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          _campaigns = data;
        } else {
          // Fallback initial list
          _campaigns = [
            {
              'id': 'camp_1',
              'name': 'Pune Property Campaign',
              'platform': 'Facebook & Instagram',
              'leads_count': 87,
              'daily_budget': 1000,
              'status': 'ACTIVE',
            },
            {
              'id': 'camp_2',
              'name': 'Mumbai Property Campaign',
              'platform': 'Facebook',
              'leads_count': 42,
              'daily_budget': 800,
              'status': 'ACTIVE',
            },
            {
              'id': 'camp_3',
              'name': 'Website Lead Campaign',
              'platform': 'Instagram',
              'leads_count': 31,
              'daily_budget': 500,
              'status': 'PAUSED',
            },
          ];
        }
        _isLoading = false;
      });
    }
  }

  void _showCreateCampaignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CreateCampaignBottomSheet(
        onCreated: (newCamp) {
          setState(() {
            _campaigns.insert(0, newCamp);
          });
        },
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> campaign) async {
    final currentStatus = campaign['status'] ?? 'ACTIVE';
    final newStatus = currentStatus == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    final id = campaign['id'] ?? campaign['meta_campaign_id'];

    if (id != null) {
      await _backend.toggleCampaignStatus(id.toString(), newStatus);
    }

    setState(() {
      campaign['status'] = newStatus;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Campaign ${campaign['name']} set to $newStatus'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Meta Campaigns',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCampaigns,
            tooltip: 'Refresh from Meta',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCampaignSheet,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Meta Campaign',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCampaigns,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                children: [
                  _buildSummary(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Campaigns',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${_campaigns.length} campaigns',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._campaigns.map(
                    (campaign) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CampaignCard(
                        campaign: campaign,
                        onToggleStatus: () => _toggleStatus(campaign),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    final totalLeads = _campaigns.fold<int>(
      0,
      (sum, c) => sum + (c['leads_count'] as int? ?? c['leads'] as int? ?? 0),
    );

    final activeCampaigns = _campaigns.where(
      (c) => (c['status'] ?? '').toString().toUpperCase() == 'ACTIVE',
    ).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Campaigns',
            value: '${_campaigns.length}',
            icon: Icons.campaign_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Active Campaigns',
            value: '$activeCampaigns',
            icon: Icons.play_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Meta Leads',
            value: '$totalLeads',
            icon: Icons.people_outline,
          ),
        ),
      ],
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
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> campaign;
  final VoidCallback onToggleStatus;

  const _CampaignCard({
    required this.campaign,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = (campaign['status'] ?? 'ACTIVE').toString().toUpperCase();
    final bool active = status == 'ACTIVE';
    final leads = campaign['leads_count'] ?? campaign['leads'] ?? 0;
    final budgetVal = campaign['daily_budget'] != null ? '₹${campaign['daily_budget']}/day' : (campaign['budget'] ?? '₹1,000/day');
    final metaId = campaign['meta_campaign_id'] ?? campaign['id'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign['name'] ?? 'Untitled Campaign',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${campaign['platform'] ?? 'Facebook & Instagram'} • ID: $metaId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleStatus,
                borderRadius: BorderRadius.circular(20),
                child: _StatusBadge(
                  text: active ? 'Active' : 'Paused',
                  active: active,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CampaignInfo(
                  label: 'Leads Captured',
                  value: '$leads',
                  icon: Icons.people_outline,
                ),
              ),
              Expanded(
                child: _CampaignInfo(
                  label: 'Daily Budget',
                  value: '$budgetVal',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CampaignInfo({
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
        Column(
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool active;

  const _StatusBadge({
    required this.text,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet to create and launch a new campaign on Meta Ads
class _CreateCampaignBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreated;

  const _CreateCampaignBottomSheet({required this.onCreated});

  @override
  State<_CreateCampaignBottomSheet> createState() => _CreateCampaignBottomSheetState();
}

class _CreateCampaignBottomSheetState extends State<_CreateCampaignBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController(text: '1000');
  final _headlineController = TextEditingController(text: 'Book Exclusive Site Visit');
  final _bodyController = TextEditingController(text: 'Explore premium residential layouts. Fill form to download pricing details.');
  
  String _selectedPlatform = 'Facebook & Instagram';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _headlineController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final res = await BackendService().createCampaign(
      name: _nameController.text.trim(),
      dailyBudget: double.tryParse(_budgetController.text.trim()) ?? 1000,
      platform: _selectedPlatform,
      headline: _headlineController.text.trim(),
      bodyText: _bodyController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        final createdData = Map<String, dynamic>.from(res['data'] ?? {});
        widget.onCreated(createdData);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Meta Ads Campaign launched and synced with Firebase!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${res['message'] ?? 'Could not create campaign'}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Meta Ads Campaign',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text(
                'Launches a Lead Generation campaign directly onto Meta Ads & saves to Firebase',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),

              // Campaign Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Campaign Name *',
                  hintText: 'e.g., Baner Prime Residences Launch',
                  prefixIcon: Icon(Icons.campaign_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a campaign name' : null,
              ),
              const SizedBox(height: 14),

              // Daily Budget & Platform Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Daily Budget (₹) *',
                        prefixText: '₹ ',
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Valid budget required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPlatform,
                      decoration: const InputDecoration(
                        labelText: 'Target Platform',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Facebook & Instagram', child: Text('FB & Instagram', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Facebook', child: Text('Facebook Only', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Instagram', child: Text('Instagram Only', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPlatform = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ad Headline
              TextFormField(
                controller: _headlineController,
                decoration: const InputDecoration(
                  labelText: 'Ad Headline',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 14),

              // Ad Body
              TextFormField(
                controller: _bodyController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ad Primary Text',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch),
                  label: Text(
                    _isSubmitting ? 'Creating on Meta Ads...' : 'Launch Meta Campaign',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}