import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'meta_setup_screen.dart';

class MetaAccountDetailsScreen extends StatefulWidget {
  final String? initialAdAccountId;

  const MetaAccountDetailsScreen({
    super.key,
    this.initialAdAccountId,
  });

  @override
  State<MetaAccountDetailsScreen> createState() => _MetaAccountDetailsScreenState();
}

class _MetaAccountDetailsScreenState extends State<MetaAccountDetailsScreen> with SingleTickerProviderStateMixin {
  final BackendService _backend = BackendService();
  late TabController _tabController;
  int _selectedTabIndex = 0;

  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedDatePreset = 'last_30d';

  // State data
  Map<String, dynamic> _diagnostics = {};
  List<Map<String, dynamic>> _adAccounts = [];
  Map<String, dynamic>? _selectedAccount;
  String? _selectedAdAccountId;

  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _adSets = [];
  List<Map<String, dynamic>> _ads = [];
  Map<String, dynamic> _insights = {};
  List<Map<String, dynamic>> _leadForms = [];
  Map<String, dynamic> _syncStatus = {};

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
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _selectedAdAccountId = widget.initialAdAccountId;
    _loadAllAccountData();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging && _selectedTabIndex != _tabController.index) {
      if (mounted) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAccountData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Diagnostics & accessible ad accounts
      final diag = await _backend.getMetaDiagnostics();
      final accounts = await _backend.getMetaAccounts();
      final syncSt = await _backend.getMetaSyncStatus();

      _diagnostics = diag;
      _adAccounts = accounts;
      _syncStatus = syncSt;

      // Select active ad account
      if (_selectedAdAccountId == null || !_adAccounts.any((a) => a['id'] == _selectedAdAccountId)) {
        if (_adAccounts.isNotEmpty) {
          _selectedAdAccountId = _adAccounts.first['id'];
        }
      }

      if (_selectedAdAccountId != null) {
        _selectedAccount = _adAccounts.firstWhere(
          (a) => a['id'] == _selectedAdAccountId,
          orElse: () => _adAccounts.isNotEmpty ? _adAccounts.first : {},
        );

        // 2. Fetch specific data for selected ad account
        final results = await Future.wait([
          _backend.getMetaCampaigns(adAccountId: _selectedAdAccountId),
          _backend.getMetaAdSets(adAccountId: _selectedAdAccountId),
          _backend.getMetaAds(adAccountId: _selectedAdAccountId),
          _backend.getMetaInsights(adAccountId: _selectedAdAccountId, datePreset: _selectedDatePreset),
          _backend.getMetaLeadForms(),
        ]);

        _campaigns = results[0] as List<Map<String, dynamic>>;
        _adSets = results[1] as List<Map<String, dynamic>>;
        _ads = results[2] as List<Map<String, dynamic>>;
        _insights = results[3] as Map<String, dynamic>;
        _leadForms = results[4] as List<Map<String, dynamic>>;
      }
    } catch (e) {
      debugPrint('[MetaAccountDetailsScreen] Error loading account data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeAdAccount(String newAccountId) async {
    if (newAccountId == _selectedAdAccountId) return;
    setState(() {
      _selectedAdAccountId = newAccountId;
      _selectedAccount = _adAccounts.firstWhere((a) => a['id'] == newAccountId, orElse: () => {});
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _backend.getMetaCampaigns(adAccountId: newAccountId),
        _backend.getMetaAdSets(adAccountId: newAccountId),
        _backend.getMetaAds(adAccountId: newAccountId),
        _backend.getMetaInsights(adAccountId: newAccountId, datePreset: _selectedDatePreset),
      ]);

      if (mounted) {
        setState(() {
          _campaigns = results[0] as List<Map<String, dynamic>>;
          _adSets = results[1] as List<Map<String, dynamic>>;
          _ads = results[2] as List<Map<String, dynamic>>;
          _insights = results[3] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncLeads() async {
    setState(() => _isSyncing = true);
    final res = await _backend.syncMetaLeads();
    final refreshedSync = await _backend.getMetaSyncStatus();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncStatus = refreshedSync;
      });

      final count = res['syncedCount'] ?? 0;
      final dups = res['duplicatesSkipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['success'] == true
              ? 'Lead Sync Complete: $count new leads imported ($dups duplicates skipped)'
              : 'Sync note: ${res['message']}'),
          backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : AppTheme.primary,
        ),
      );
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAdAccountPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _adAccounts.where((a) {
              final name = (a['name'] ?? '').toString().toLowerCase();
              final id = (a['id'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase()) || id.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Select Meta Ad Account',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '${_adAccounts.length} Accessible',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by account name or ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching ad accounts found',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.border),
                            itemBuilder: (context, idx) {
                              final acc = filtered[idx];
                              final isSelected = acc['id'] == _selectedAdAccountId;
                              final spend = (double.tryParse('${acc['amountSpent'] ?? 0}') ?? 0) / 100;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  acc['name'] ?? 'Ad Account',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${acc['id']} • ${acc['currency'] ?? 'INR'} • ₹${spend.toStringAsFixed(2)} spent',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 20)
                                    : const Icon(Icons.chevron_right, color: AppTheme.border, size: 18),
                                onTap: () {
                                  final newId = acc['id'];
                                  Navigator.pop(ctx);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      _changeAdAccount(newId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meta Account Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              'Official Meta Graph API • ${_diagnostics['user']?['name'] ?? 'Connected'}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllAccountData,
            tooltip: 'Refresh All Meta Data',
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Fetching Meta Ads assets & insights...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllAccountData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  _buildProfileHeaderCard(),
                  const SizedBox(height: 12),
                  _buildAccountSwitcherCard(),
                  const SizedBox(height: 12),
                  _buildDateFilterRow(),
                  const SizedBox(height: 16),
                  _buildTabBar(),
                  const SizedBox(height: 14),
                  _buildTabContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final user = _diagnostics['user'] as Map<String, dynamic>? ?? {};
    final userName = user['name'] ?? 'Meta User';
    final userId = user['id'] ?? 'N/A';
    final appId = _diagnostics['appId'] ?? '1392782943019273';
    final tokenType = _diagnostics['type'] ?? 'USER';
    final isValid = _diagnostics['tokenValid'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF0052CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.facebook, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isValid ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isValid ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            isValid ? 'Token Valid' : 'Check Token',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'User ID: $userId • App ID: $appId',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderInfoItem(label: 'Token Type', value: '$tokenType Token'),
              _HeaderInfoItem(label: 'Access Mode', value: 'Read-Only Safe'),
              _HeaderInfoItem(label: 'Ad Accounts', value: '${_adAccounts.length} Linked'),
              _HeaderInfoItem(label: 'API Version', value: 'v21.0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSwitcherCard() {
    final acc = _selectedAccount ?? {};
    final name = acc['name'] ?? 'Ad Account';
    final id = acc['id'] ?? 'act_000';
    final currency = acc['currency'] ?? 'INR';
    final tz = acc['timezone'] ?? 'Asia/Kolkata';
    final status = acc['status'] == 1 || acc['status'] == 'ACTIVE' ? 'ACTIVE' : 'INACTIVE';
    final rawSpend = double.tryParse('${acc['amountSpent'] ?? 0}') ?? 0;
    final spendFormatted = rawSpend > 0 ? (rawSpend / 100).toStringAsFixed(2) : '0.00';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Ad Account', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showAdAccountPicker,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _copy(id, 'Ad Account ID'),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ID: $id',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                Text('• $currency • $tz • ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'ACTIVE' ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'ACTIVE' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Spent: ₹$spendFormatted', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary)),
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
                  _loadAllAccountData();
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
            ),
          );
        }).toList(),
      ),
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
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
          Tab(text: 'Insights (${_selectedDatePreset.replaceAll('_', ' ').toUpperCase()})'),
          Tab(text: 'Campaigns (${_campaigns.length})'),
          Tab(text: 'Ad Sets (${_adSets.length})'),
          Tab(text: 'Ads (${_ads.length})'),
          Tab(text: 'Lead Forms (${_leadForms.length})'),
          const Tab(text: 'Permissions & Security'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return KeyedSubtree(
      key: ValueKey<int>(_selectedTabIndex),
      child: _getTabContent(_selectedTabIndex),
    );
  }

  Widget _getTabContent(int index) {
    switch (index) {
      case 0:
        return _buildInsightsTab();
      case 1:
        return _buildCampaignsTab();
      case 2:
        return _buildAdSetsTab();
      case 3:
        return _buildAdsTab();
      case 4:
        return _buildLeadFormsTab();
      case 5:
        return _buildPermissionsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInsightsTab() {
    final summary = _insights['summary'] as Map<String, dynamic>? ?? {};
    final spend = double.tryParse('${summary['spend'] ?? 0}') ?? 0;
    final leads = int.tryParse('${summary['leads'] ?? 0}') ?? 0;
    final impressions = int.tryParse('${summary['impressions'] ?? 0}') ?? 0;
    final clicks = int.tryParse('${summary['clicks'] ?? 0}') ?? 0;
    final reach = int.tryParse('${summary['reach'] ?? 0}') ?? 0;
    final ctr = double.tryParse('${summary['ctr'] ?? 0}') ?? 0;
    final cpc = double.tryParse('${summary['cpc'] ?? 0}') ?? 0;
    final cpl = leads > 0 ? spend / leads : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DetailMetricCard(
                title: 'Total Spend',
                value: '₹${spend.toStringAsFixed(2)}',
                subtitle: 'Period: ${_selectedDatePreset.replaceAll('_', ' ')}',
                icon: Icons.payments_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DetailMetricCard(
                title: 'Meta Leads',
                value: '$leads',
                subtitle: leads > 0 ? '₹${cpl.toStringAsFixed(1)} / lead' : 'No form leads yet',
                icon: Icons.assignment_ind_outlined,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DetailMetricCard(
                title: 'Impressions & Reach',
                value: '$impressions',
                subtitle: 'Reach: $reach',
                icon: Icons.visibility_outlined,
                color: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DetailMetricCard(
                title: 'Clicks & CTR',
                value: '$clicks',
                subtitle: '${ctr.toStringAsFixed(2)}% CTR • ₹${cpc.toStringAsFixed(2)} CPC',
                icon: Icons.touch_app_outlined,
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Performance Summary Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              _MetricRow(label: 'Total Reporting Level', value: 'Account Level'),
              _MetricRow(label: 'Target Ad Account ID', value: _selectedAdAccountId ?? 'N/A'),
              _MetricRow(label: 'Currency Configured', value: _selectedAccount?['currency'] ?? 'INR'),
              _MetricRow(label: 'Cost Per 1,000 Impressions (CPM)', value: '₹${summary['cpm'] ?? '0.00'}'),
              _MetricRow(label: 'Frequency of Delivery', value: '${summary['frequency'] ?? '1.0'}'),
              _MetricRow(label: 'Link Clicks', value: '${summary['linkClicks'] ?? clicks}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignsTab() {
    if (_campaigns.isEmpty) {
      return _buildEmptyState('No Campaigns in this Ad Account', 'Switch ad accounts above to view campaigns in other accounts.');
    }

    return Column(
      children: _campaigns.map((camp) {
        final status = (camp['effectiveStatus'] ?? camp['status'] ?? 'ACTIVE').toString().toUpperCase();
        final isActive = status == 'ACTIVE';
        final spend = camp['spend'] ?? 0;
        final leads = camp['leads'] ?? camp['leadsCount'] ?? 0;
        final dailyBudget = camp['dailyBudget'] != null ? '₹${camp['dailyBudget']}' : 'Auto';
        final objective = camp['objective'] ?? 'OUTCOME_LEADS';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.campaign, color: isActive ? AppTheme.primary : AppTheme.textSecondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(camp['name'] ?? 'Campaign', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => _copy('${camp['id']}', 'Campaign ID'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ID: ${camp['id']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy, size: 10, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text('Objective: $objective', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricPill(label: 'Daily Budget', value: dailyBudget),
                  _MetricPill(label: 'Spent', value: '₹$spend'),
                  _MetricPill(label: 'Leads', value: '$leads'),
                  _MetricPill(label: 'CTR', value: '${camp['ctr'] ?? '0.00'}%'),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdSetsTab() {
    if (_adSets.isEmpty) {
      return _buildEmptyState('No Ad Sets Found', 'There are no active or historical ad sets recorded for this ad account.');
    }

    return Column(
      children: _adSets.map((as) {
        final status = (as['effectiveStatus'] ?? as['status'] ?? 'ACTIVE').toString().toUpperCase();
        final isActive = status == 'ACTIVE';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers_outlined, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(as['name'] ?? 'Ad Set', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('ID: ${as['id']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
      }).toList(),
    );
  }

  Widget _buildAdsTab() {
    if (_ads.isEmpty) {
      return _buildEmptyState('No Advertisements Found', 'Ads in this account will be listed here with creative previews and metrics.');
    }

    return Column(
      children: _ads.map((ad) {
        final creative = ad['creative'] as Map<String, dynamic>? ?? {};
        final status = (ad['effectiveStatus'] ?? ad['status'] ?? 'ACTIVE').toString().toUpperCase();
        final isActive = status == 'ACTIVE';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: creative['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.network(
                              creative['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, size: 22),
                            ),
                          )
                        : const Icon(Icons.image_outlined, size: 22, color: AppTheme.textSecondary),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              if (creative['body'] != null) ...[
                const SizedBox(height: 10),
                Text(creative['body'], style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
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

  Widget _buildLeadFormsTab() {
    final syncRaw = _syncStatus['lastSyncTime']?.toString();
    final parsedTime = syncRaw != null ? DateTime.tryParse(syncRaw)?.toLocal().toString().split('.')[0] : null;
    final lastSyncTime = parsedTime ?? 'Never';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sync, color: Color(0xFF16A34A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lead Ads Synchronization', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('Sync Instant Forms into Eligible CRM database without duplicates.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Synchronized', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text(lastSyncTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
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
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Leads Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Facebook Page & Lead Forms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Eligible.com', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricRow(label: 'Connected Page ID', value: '1354679121056277'),
              _MetricRow(label: 'Category', value: 'Loan Service'),
              _MetricRow(label: 'Total Lead Forms Discovered', value: '${_leadForms.length}'),
              _MetricRow(label: 'Realtime Webhook', value: '/api/webhooks/meta (HMAC SHA-256)'),
              if (_leadForms.isEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'No forms currently open or created on Eligible.com. When forms are created in Ads Manager, they will appear here.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ..._leadForms.map((f) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f['name'] ?? 'Lead Form', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Text('${f['leadsCount'] ?? 0} leads', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    final granted = List<String>.from(_diagnostics['grantedPermissions'] ?? []);
    final checks = _diagnostics['permissionChecks'] as Map<String, dynamic>? ?? {};

    final requiredPermissions = [
      {'scope': 'ads_read', 'desc': 'Read ad accounts, campaigns, ads and performance metrics'},
      {'scope': 'leads_retrieval', 'desc': 'Retrieve submitted instant form lead details'},
      {'scope': 'pages_read_engagement', 'desc': 'Access Facebook Page details and webhooks'},
      {'scope': 'pages_manage_ads', 'desc': 'Manage and access Lead Ads forms for pages'},
      {'scope': 'pages_show_list', 'desc': 'View list of accessible Facebook pages'},
      {'scope': 'ads_management', 'desc': 'Marketing API management permissions'},
      {'scope': 'business_management', 'desc': 'Manage business assets and accounts'},
      {'scope': 'pages_messaging', 'desc': 'Page messaging and inquiry integration'},
      {'scope': 'whatsapp_business_management', 'desc': 'WhatsApp Business Cloud assets'},
    ];

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meta Token Diagnostics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('Inspect verified OAuth permissions granted to your token.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MetricRow(label: 'Token Expiry', value: _diagnostics['expiresAt'] ?? 'Active'),
          _MetricRow(label: 'Data Access Expiry', value: _diagnostics['dataAccessExpiresAt'] ?? '2027'),
          _MetricRow(label: 'App ID', value: '${_diagnostics['appId'] ?? '1392782943019273'}'),
          _MetricRow(label: 'Read-Only Guard', value: 'Enforced (No modifications to live ads)'),
          const SizedBox(height: 14),
          const Text('Granted Permissions Scopes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...requiredPermissions.map((item) {
            final scope = item['scope']!;
            final isGranted = granted.contains(scope) || checks[scope] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isGranted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isGranted ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Icon(
                    isGranted ? Icons.check_circle : Icons.cancel_outlined,
                    color: isGranted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scope, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(item['desc']!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    isGranted ? 'Active' : 'Missing',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isGranted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 36, color: AppTheme.textSecondary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _HeaderInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderInfoItem({required this.label, required this.value});

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

class _DetailMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DetailMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
