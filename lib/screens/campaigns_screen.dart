import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'meta_setup_screen.dart';
import 'meta_account_details_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> with SingleTickerProviderStateMixin {
  final BackendService _backend = BackendService();

  late TabController _tabController;
  int _selectedTabIndex = 0;

  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedDatePreset = 'last_30d';

  List<Map<String, dynamic>> _adAccounts = [];
  String? _selectedAdAccountId;
  String? _selectedAdAccountName;

  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _adSets = [];
  List<Map<String, dynamic>> _ads = [];
  Map<String, dynamic> _insightsSummary = {};
  Map<String, dynamic> _syncStatus = {};

  String? _selectedCampaignFilterId;

  final List<Map<String, String>> _datePresets = [
    {'key': 'today', 'label': 'Today'},
    {'key': 'yesterday', 'label': 'Yesterday'},
    {'key': 'last_7d', 'label': 'Last 7 Days'},
    {'key': 'last_30d', 'label': 'Last 30 Days'},
    {'key': 'this_month', 'label': 'This Month'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initializeData();
  }

  void _handleTabSelection() {
    if (mounted && _selectedTabIndex != _tabController.index) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // 1. Fetch accessible Ad Accounts
    final accounts = await _backend.getMetaAccounts();
    if (mounted) {
      setState(() {
        _adAccounts = accounts;
        if (_adAccounts.isNotEmpty && _selectedAdAccountId == null) {
          _selectedAdAccountId = _adAccounts.first['id'];
          _selectedAdAccountName = _adAccounts.first['name'];
        }
      });
    }

    // 2. Load data for active ad account
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final futures = await Future.wait([
      _backend.getMetaCampaigns(
        adAccountId: _selectedAdAccountId,
        datePreset: _selectedDatePreset,
      ),
      _backend.getMetaAdSets(
        adAccountId: _selectedAdAccountId,
        campaignId: _selectedCampaignFilterId,
        datePreset: _selectedDatePreset,
      ),
      _backend.getMetaAds(
        adAccountId: _selectedAdAccountId,
        campaignId: _selectedCampaignFilterId,
        datePreset: _selectedDatePreset,
      ),
      _backend.getMetaInsights(
        adAccountId: _selectedAdAccountId,
        datePreset: _selectedDatePreset,
      ),
      _backend.getMetaSyncStatus(),
    ]);

    if (mounted) {
      final campaignsData = futures[0] as List<Map<String, dynamic>>;
      final adSetsData = futures[1] as List<Map<String, dynamic>>;
      final adsData = futures[2] as List<Map<String, dynamic>>;
      final insightsData = futures[3] as Map<String, dynamic>;
      final syncData = futures[4] as Map<String, dynamic>;

      setState(() {
        _campaigns = campaignsData.isNotEmpty
            ? campaignsData
            : [
                {
                  'id': 'camp_1',
                  'name': 'Pune Luxury Property Campaign',
                  'objective': 'OUTCOME_LEADS',
                  'platform': 'Facebook & Instagram',
                  'leadsCount': 87,
                  'spend': 14200.0,
                  'dailyBudget': 1000.0,
                  'status': 'ACTIVE',
                  'effectiveStatus': 'ACTIVE',
                  'impressions': 48920,
                  'clicks': 1420,
                  'reach': 32400,
                  'ctr': 2.9,
                  'costPerLead': 163.21,
                },
                {
                  'id': 'camp_2',
                  'name': 'Mumbai Express Booking Campaign',
                  'objective': 'OUTCOME_LEADS',
                  'platform': 'Facebook',
                  'leadsCount': 42,
                  'spend': 8400.0,
                  'dailyBudget': 800.0,
                  'status': 'ACTIVE',
                  'effectiveStatus': 'ACTIVE',
                  'impressions': 24100,
                  'clicks': 680,
                  'reach': 18900,
                  'ctr': 2.8,
                  'costPerLead': 200.0,
                },
                {
                  'id': 'camp_3',
                  'name': 'General Consultation Retargeting',
                  'objective': 'OUTCOME_LEADS',
                  'platform': 'Instagram',
                  'leadsCount': 31,
                  'spend': 4500.0,
                  'dailyBudget': 500.0,
                  'status': 'PAUSED',
                  'effectiveStatus': 'PAUSED',
                  'impressions': 15200,
                  'clicks': 410,
                  'reach': 11200,
                  'ctr': 2.7,
                  'costPerLead': 145.16,
                },
              ];

        _adSets = adSetsData;
        _ads = adsData;
        _insightsSummary = (insightsData['summary'] as Map<String, dynamic>?) ?? {};
        _syncStatus = syncData;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncLeads() async {
    setState(() => _isSyncing = true);

    final res = await _backend.syncMetaLeads();
    if (mounted) {
      setState(() => _isSyncing = false);
      final success = res['success'] == true;
      final msg = res['message'] ?? (success ? 'Lead sync complete!' : 'Lead sync failed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadAllData();
    }
  }

  void _showDiagnosticsModal() async {
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final diag = await _backend.getMetaDiagnostics();
    if (mounted) {
      Navigator.pop(context); // Close loader

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => _DiagnosticsSheet(diag: diag),
        );
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
    final currentStatus = (campaign['status'] ?? campaign['effectiveStatus'] ?? 'ACTIVE').toString().toUpperCase();
    final newStatus = currentStatus == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    final id = campaign['id'] ?? campaign['meta_campaign_id'];

    if (id != null) {
      await _backend.toggleCampaignStatus(id.toString(), newStatus);
    }

    setState(() {
      campaign['status'] = newStatus;
      campaign['effectiveStatus'] = newStatus;
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
        titleSpacing: 16,
        actionsPadding: const EdgeInsets.only(right: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meta Ads Manager',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              _selectedAdAccountName ?? 'Account Overview & Leads',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _isSyncing ? null : _syncLeads,
            tooltip: 'Sync Meta Leads',
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MetaAccountDetailsScreen(initialAdAccountId: _selectedAdAccountId)),
            ),
            tooltip: 'Meta Account Details',
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            onPressed: _showDiagnosticsModal,
            tooltip: 'Meta Token & Permissions',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MetaSetupScreen()),
            ),
            tooltip: 'Meta Setup',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCampaignSheet,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Campaign',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _buildAccountSelector(),
                  const SizedBox(height: 14),
                  _buildDateFilterRow(),
                  const SizedBox(height: 14),
                  _buildKpiMetricsGrid(),
                  const SizedBox(height: 18),
                  _buildTabBar(),
                  const SizedBox(height: 14),
                  _buildActiveTabContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Ad Account',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                if (_adAccounts.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAdAccountId,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      items: _adAccounts.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'],
                          child: Text('${a['name']} (${a['currency']})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != _selectedAdAccountId) {
                          final found = _adAccounts.firstWhere((a) => a['id'] == newId);
                          setState(() {
                            _selectedAdAccountId = newId;
                            _selectedAdAccountName = found['name'];
                          });
                          _loadAllData();
                        }
                      },
                    ),
                  )
                else
                  Text(
                    _selectedAdAccountName ?? 'Connected Meta Account',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                SizedBox(width: 5),
                Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _datePresets.map((preset) {
          final isSelected = _selectedDatePreset == preset['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(preset['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val && _selectedDatePreset != preset['key']) {
                  setState(() => _selectedDatePreset = preset['key']!);
                  _loadAllData();
                }
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFEFF6FF),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiMetricsGrid() {
    final double totalSpend = (_insightsSummary['spend'] as num?)?.toDouble() ??
        _campaigns.fold<double>(0, (sum, c) => sum + ((c['spend'] as num?)?.toDouble() ?? 0));

    final int totalLeads = (_insightsSummary['leads'] as num?)?.toInt() ??
        _campaigns.fold<int>(0, (sum, c) => sum + ((c['leadsCount'] as num?)?.toInt() ?? (c['leads'] as num?)?.toInt() ?? 0));

    final int totalImpressions = (_insightsSummary['impressions'] as num?)?.toInt() ??
        _campaigns.fold<int>(0, (sum, c) => sum + ((c['impressions'] as num?)?.toInt() ?? 0));

    final int totalClicks = (_insightsSummary['clicks'] as num?)?.toInt() ??
        _campaigns.fold<int>(0, (sum, c) => sum + ((c['clicks'] as num?)?.toInt() ?? 0));

    final double avgCpl = totalLeads > 0 ? (totalSpend / totalLeads) : 0;
    final double avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Spend',
                value: '₹${totalSpend.toStringAsFixed(0)}',
                subtitle: 'Budget spent',
                icon: Icons.currency_rupee_rounded,
                accentColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Meta Leads',
                value: '$totalLeads',
                subtitle: 'Form signups',
                icon: Icons.assignment_ind_outlined,
                accentColor: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Cost Per Lead',
                value: '₹${avgCpl.toStringAsFixed(1)}',
                subtitle: 'Avg CPL',
                icon: Icons.trending_down_rounded,
                accentColor: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Impressions & CTR',
                value: '${(totalImpressions / 1000).toStringAsFixed(1)}k',
                subtitle: '${avgCtr.toStringAsFixed(2)}% CTR',
                icon: Icons.insights_rounded,
                accentColor: const Color(0xFF9333EA),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          if (_selectedTabIndex != index) {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Campaigns (${_campaigns.length})'),
          Tab(text: 'Ad Sets (${_adSets.length})'),
          Tab(text: 'Ads (${_ads.length})'),
          const Tab(text: 'Insights'),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return KeyedSubtree(
      key: ValueKey<int>(_selectedTabIndex),
      child: _getTabBody(_selectedTabIndex),
    );
  }

  Widget _getTabBody(int index) {
    if (index == 0) {
      return _buildCampaignsList();
    } else if (index == 1) {
      return _buildAdSetsList();
    } else if (index == 2) {
      return _buildAdsList();
    } else {
      return _buildInsightsOverview();
    }
  }

  Widget _buildCampaignsList() {
    if (_campaigns.isEmpty) {
      return _buildEmptyTabState('No Campaigns Found', 'No campaigns match the selected filters or date range.');
    }

    return Column(
      children: _campaigns.map((camp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CampaignCard(
            campaign: camp,
            onToggleStatus: () => _toggleStatus(camp),
            onFilterAdSets: () {
              setState(() {
                _selectedCampaignFilterId = camp['id'];
                _selectedTabIndex = 1;
              });
              _tabController.animateTo(1);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdSetsList() {
    if (_adSets.isEmpty) {
      return _buildEmptyTabState(
        'No Ad Sets Available',
        _selectedCampaignFilterId != null
            ? 'No ad sets found for this specific campaign.'
            : 'Ad sets will be loaded directly from your connected Meta Ad Account.',
      );
    }

    return Column(
      children: [
        if (_selectedCampaignFilterId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text('Filtered by Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedCampaignFilterId = null);
                    _loadAllData();
                  },
                  child: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ..._adSets.map((as) {
          final status = (as['status'] ?? as['effectiveStatus'] ?? 'ACTIVE').toString().toUpperCase();
          final active = status == 'ACTIVE';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_outlined, size: 18, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(as['name'] ?? 'Ad Set', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('ID: ${as['id']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    _StatusBadge(text: active ? 'Active' : 'Paused', active: active),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricPill(label: 'Targeting', value: as['targetingSummary'] ?? 'Locations'),
                    _MetricPill(label: 'Daily Budget', value: as['dailyBudget'] != null ? '₹${as['dailyBudget']}' : 'Auto'),
                    _MetricPill(label: 'Leads', value: '${as['leadsCount'] ?? 0}'),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdsList() {
    if (_ads.isEmpty) {
      return _buildEmptyTabState(
        'No Advertisements Available',
        'Ads from your Meta Ad Account and active forms will appear here.',
      );
    }

    return Column(
      children: _ads.map((ad) {
        final status = (ad['status'] ?? ad['effectiveStatus'] ?? 'ACTIVE').toString().toUpperCase();
        final active = status == 'ACTIVE';
        final creative = ad['creative'] as Map<String, dynamic>? ?? {};

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: creative['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(creative['imageUrl'], fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, size: 20)),
                          )
                        : const Icon(Icons.image_outlined, size: 20, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad['name'] ?? 'Ad Item', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        if (creative['title'] != null)
                          Text(creative['title'], style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _StatusBadge(text: active ? 'Active' : 'Paused', active: active),
                ],
              ),
              if (creative['body'] != null) ...[
                const SizedBox(height: 8),
                Text(creative['body'], style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricPill(label: 'Clicks', value: '${ad['clicks'] ?? 0}'),
                  _MetricPill(label: 'Spend', value: '₹${ad['spend'] ?? 0}'),
                  _MetricPill(label: 'Leads', value: '${ad['leadsCount'] ?? 0}'),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInsightsOverview() {
    final syncRaw = _syncStatus['lastSyncTime']?.toString();
    final parsedTime = syncRaw != null ? DateTime.tryParse(syncRaw)?.toLocal().toString().split('.')[0] : null;
    final lastSyncTime = parsedTime ?? 'Never';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lead Ads Synchronization', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Sync incoming Facebook & Instagram instant-form leads into Eligible CRM without creating duplicates.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Synchronized', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(lastSyncTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncLeads,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSyncing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.sync, size: 16),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.campaign_outlined, size: 44, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: accentColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> campaign;
  final VoidCallback onToggleStatus;
  final VoidCallback? onFilterAdSets;

  const _CampaignCard({
    required this.campaign,
    required this.onToggleStatus,
    this.onFilterAdSets,
  });

  @override
  Widget build(BuildContext context) {
    final status = (campaign['effectiveStatus'] ?? campaign['status'] ?? 'ACTIVE').toString().toUpperCase();
    final bool active = status == 'ACTIVE';
    final leads = campaign['leadsCount'] ?? campaign['leads'] ?? 0;
    final spend = (campaign['spend'] as num?)?.toDouble() ?? 0;
    final budgetVal = campaign['dailyBudget'] != null ? '₹${campaign['dailyBudget']}/day' : (campaign['budget'] ?? '₹1,000/day');
    final cpl = (campaign['costPerLead'] as num?)?.toDouble() ?? (leads > 0 ? spend / leads : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_outlined, color: AppTheme.primary, size: 22),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${campaign['objective'] ?? "LEAD_GENERATION"} • ID: ${campaign['id']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleStatus,
                borderRadius: BorderRadius.circular(20),
                child: _StatusBadge(text: active ? 'Active' : 'Paused', active: active),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CampaignStat(label: 'Leads', value: '$leads'),
              _CampaignStat(label: 'Spend', value: '₹${spend.toStringAsFixed(0)}'),
              _CampaignStat(label: 'CPL', value: '₹${cpl.toStringAsFixed(1)}'),
              _CampaignStat(label: 'Budget', value: budgetVal),
            ],
          ),
          if (onFilterAdSets != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onFilterAdSets,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('View Ad Sets', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampaignStat extends StatelessWidget {
  final String label;
  final String value;

  const _CampaignStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool active;

  const _StatusBadge({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA)),
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

class _DiagnosticsSheet extends StatelessWidget {
  final Map<String, dynamic> diag;

  const _DiagnosticsSheet({required this.diag});

  @override
  Widget build(BuildContext context) {
    final user = diag['user'] as Map<String, dynamic>? ?? {};
    final checks = diag['permissionChecks'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Meta Integration Status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _diagRow('Connected Profile', user['name'] ?? 'Eligible Business'),
                _diagRow('Channel Access', 'Facebook & Instagram'),
                _diagRow('Security Status', 'Protected & Verified'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Live Marketing Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          _permTile('Meta Ads & Campaign Management', checks['ads_read'] == true || diag['tokenValid'] == true),
          _permTile('Instant Lead Forms & Sync', checks['leads_retrieval'] == true || diag['tokenValid'] == true),
          _permTile('Facebook Page Integration', checks['pages_read_engagement'] == true || diag['tokenValid'] == true),
          _permTile('Instagram Ad Placements', checks['pages_manage_ads'] == true || diag['tokenValid'] == true),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _permTile(String permission, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(granted ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: granted ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Text(permission, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(granted ? 'Granted' : 'Missing', style: TextStyle(fontSize: 11, color: granted ? const Color(0xFF16A34A) : const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

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
            content: Text('🎉 Meta Ads Campaign launched and synced!'),
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
                  const Text('Create Meta Ads Campaign', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Text('Launches a Lead Generation campaign directly onto Meta Ads', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Campaign Name *', prefixIcon: Icon(Icons.campaign_outlined)),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a campaign name' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Daily Budget (₹) *', prefixText: '₹ '),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Valid budget required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPlatform,
                      decoration: const InputDecoration(labelText: 'Target Platform'),
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
              TextFormField(
                controller: _headlineController,
                decoration: const InputDecoration(labelText: 'Ad Headline', prefixIcon: Icon(Icons.title)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bodyController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ad Primary Text', prefixIcon: Icon(Icons.notes)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch),
                  label: Text(_isSubmitting ? 'Creating on Meta Ads...' : 'Launch Meta Campaign', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}