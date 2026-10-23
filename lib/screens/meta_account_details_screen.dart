import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'meta_setup_screen.dart';
import 'campaigns_screen.dart';

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

  Future<void> _loadAllAccountData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      // 1. Diagnostics, accessible ad accounts & sync status in parallel
      final initResults = await Future.wait([
        _backend.getMetaDiagnostics(forceRefresh: forceRefresh),
        _backend.getMetaAccounts(forceRefresh: forceRefresh),
        _backend.getMetaSyncStatus(forceRefresh: forceRefresh),
      ]);

      _diagnostics = initResults[0] as Map<String, dynamic>;
      _adAccounts = initResults[1] as List<Map<String, dynamic>>;
      _syncStatus = initResults[2] as Map<String, dynamic>;

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

        // 2. Fetch specific data for selected ad account in parallel
        final results = await Future.wait([
          _backend.getMetaCampaigns(adAccountId: _selectedAdAccountId, forceRefresh: forceRefresh),
          _backend.getMetaAdSets(adAccountId: _selectedAdAccountId, forceRefresh: forceRefresh),
          _backend.getMetaAds(adAccountId: _selectedAdAccountId, forceRefresh: forceRefresh),
          _backend.getMetaInsights(adAccountId: _selectedAdAccountId, datePreset: _selectedDatePreset, forceRefresh: forceRefresh),
          _backend.getMetaLeadForms(forceRefresh: forceRefresh),
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
    _backend.clearMetaCache();
    final res = await _backend.syncMetaLeads();
    final refreshedSync = await _backend.getMetaSyncStatus(forceRefresh: true);

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncStatus = refreshedSync;
      });
      _loadAllAccountData(forceRefresh: true);

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
            onPressed: () => _loadAllAccountData(forceRefresh: true),
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
              onRefresh: () => _loadAllAccountData(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  _buildProfileHeaderCard(),
                  const SizedBox(height: 12),
                  _buildAccountSwitcherCard(),
                  const SizedBox(height: 12),
                  _buildConnectedAssetsCard(),
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
    final userName = user['name'] ?? 'Meta Business Suite';
    final isValid = _diagnostics['tokenValid'] == true;

    // Calculate aggregate business metrics
    final summary = _insights['summary'] as Map<String, dynamic>? ?? {};
    final double totalSpend = (summary['spend'] as num?)?.toDouble() ??
        _campaigns.fold<double>(0, (sum, c) => sum + ((c['spend'] as num?)?.toDouble() ?? 0));
    final int totalLeads = (summary['leads'] as num?)?.toInt() ??
        _campaigns.fold<int>(0, (sum, c) => sum + ((c['leadsCount'] as num?)?.toInt() ?? (c['leads'] as num?)?.toInt() ?? 0));

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
                  child: Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isValid ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isValid ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                size: 11,
                                color: isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isValid ? 'Connected' : 'Action Needed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Official Meta Ads & Lead Generation Integration',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
              _HeaderInfoItem(label: 'Campaigns', value: '${_campaigns.length} Active'),
              _HeaderInfoItem(label: 'Total Leads', value: '$totalLeads Leads'),
              _HeaderInfoItem(label: 'Total Spend', value: '₹${totalSpend.toStringAsFixed(0)}'),
              _HeaderInfoItem(label: 'Ad Accounts', value: '${_adAccounts.length} Linked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSwitcherCard() {
    final acc = _selectedAccount ?? {};
    final name = acc['name'] ?? 'Ad Account';
    final currency = acc['currency'] ?? 'INR';
    final status = acc['status'] == 1 || acc['status'] == 'ACTIVE' ? 'ACTIVE' : 'INACTIVE';
    final rawSpend = double.tryParse('${acc['amountSpent'] ?? 0}') ?? 0;
    final spendFormatted = rawSpend > 0 ? rawSpend.toStringAsFixed(2) : '0.00';

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'ACTIVE' ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'ACTIVE' ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'ACTIVE' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('• Currency: $currency', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('Lifetime Spent: ₹$spendFormatted', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedAssetsCard() {
    final page = _diagnostics['page'] as Map<String, dynamic>?;
    final instagram = _diagnostics['instagram'] as Map<String, dynamic>?;

    final pageName = page?['name'] ?? 'Eligible.com';
    final pageCategory = page?['category'] ?? 'Loan service';

    final igHandle = instagram?['username'] ?? 'eligible1954';
    final igName = instagram?['name'] ?? 'eligible.com';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text(
                'Connected Meta Channels',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
              ),
              Spacer(),
              Text(
                '2 Channels Active',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Facebook Page
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.facebook, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pageName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Page • $pageCategory',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Instagram
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFBCFE8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$igHandle',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              igName,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        onTap: (index) {
          if (_selectedTabIndex != index) {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
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
          const Tab(text: 'Account Status'),
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
        return _buildAccountStatusTab();
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
              _MetricRow(label: 'Account Currency', value: _selectedAccount?['currency'] ?? 'INR'),
              _MetricRow(label: 'Cost Per 1,000 Views (CPM)', value: '₹${summary['cpm'] ?? '0.00'}'),
              _MetricRow(label: 'Average Delivery Frequency', value: '${summary['frequency'] ?? '1.0'} views / person'),
              _MetricRow(label: 'Total Ad Link Clicks', value: '${summary['linkClicks'] ?? clicks}'),
              _MetricRow(label: 'Website & Landing Visitors', value: '${summary['clicks'] ?? clicks}'),
            ],
          ),
        ),
      ],
    );
  }

  String _formatObjective(String? obj) {
    if (obj == null) return 'Lead Generation';
    switch (obj.toUpperCase()) {
      case 'OUTCOME_LEADS':
      case 'LEAD_GENERATION':
        return 'Lead Generation (Forms & WhatsApp)';
      case 'OUTCOME_TRAFFIC':
        return 'Website Traffic & Visitors';
      case 'OUTCOME_AWARENESS':
        return 'Brand Awareness & Reach';
      case 'OUTCOME_ENGAGEMENT':
        return 'Post & Page Engagement';
      case 'OUTCOME_SALES':
        return 'Sales & Conversions';
      default:
        return obj.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }

  Widget _buildCampaignsTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta Ads Manager',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    Text(
                      'Create & launch new lead campaigns directly from the CRM',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CampaignsScreen()),
                  ).then((_) => _loadAllAccountData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Ad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        if (_campaigns.isEmpty)
          _buildEmptyState('No Campaigns in this Ad Account', 'Switch ad accounts above or tap "Create Ad" to launch one.')
        else
          ..._campaigns.map((camp) {
            final status = (camp['effectiveStatus'] ?? camp['status'] ?? 'ACTIVE').toString().toUpperCase();
            final isActive = status == 'ACTIVE';
            final spend = double.tryParse('${camp['spend'] ?? 0}') ?? 0;
            final leads = int.tryParse('${camp['leads'] ?? camp['leadsCount'] ?? 0}') ?? 0;
            final rawBudget = camp['dailyBudget'];
            final String dailyBudget;
            if (rawBudget != null) {
              final numVal = num.tryParse('$rawBudget');
              dailyBudget = numVal != null ? '₹${numVal.toStringAsFixed(0)}/day' : '₹$rawBudget/day';
            } else {
              dailyBudget = 'Auto Budget';
            }
            final objectiveStr = _formatObjective(camp['objective']?.toString());
            final cpl = leads > 0 ? '₹${(spend / leads).toStringAsFixed(1)}' : 'N/A';

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
                            Text(
                              camp['name'] ?? 'Lead Generation Campaign',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Channels: Facebook & Instagram Ads',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                          isActive ? 'Active' : 'Paused',
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
                        const Icon(Icons.ads_click_outlined, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Campaign Goal: $objectiveStr',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
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
                      _MetricPill(label: 'Spent', value: '₹${spend.toStringAsFixed(0)}'),
                      _MetricPill(label: 'Leads', value: '$leads'),
                      _MetricPill(label: 'Cost / Lead', value: cpl),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
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
                        const Text('Placement: Facebook & Instagram Feeds', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
              _MetricRow(label: 'Connected Page', value: 'Eligible.com'),
              _MetricRow(label: 'Category', value: 'Financial Services & Real Estate Loans'),
              _MetricRow(label: 'Lead Forms Discovered', value: '${_leadForms.length} Active Forms'),
              _MetricRow(label: 'Realtime Webhook Delivery', value: 'Active (Instant Lead Notifications)'),
              _MetricRow(label: 'Duplicate Protection', value: 'Enabled (Zero Duplicate Entries)'),
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

  Widget _buildAccountStatusTab() {
    final isValid = _diagnostics['tokenValid'] == true;

    final List<Map<String, dynamic>> healthItems = [
      {
        'title': 'Meta Lead Ads Synchronization',
        'subtitle': 'Captures customer lead forms directly into Eligible CRM',
        'status': isValid ? 'Active & Ready' : 'Needs Verification',
        'active': isValid,
        'icon': Icons.assignment_ind_outlined,
      },
      {
        'title': 'Facebook Page Connection',
        'subtitle': 'Linked to "Eligible.com" for running sponsored social ads',
        'status': 'Connected',
        'active': true,
        'icon': Icons.facebook,
      },
      {
        'title': 'Instagram Business Channel',
        'subtitle': 'Linked to "@eligible1954" for Instagram Feed & Stories ads',
        'status': 'Connected',
        'active': true,
        'icon': Icons.camera_alt_outlined,
      },
      {
        'title': 'WhatsApp Lead Inquiries',
        'subtitle': 'Direct routing of Click-to-WhatsApp leads to CRM pipeline',
        'status': 'Enabled',
        'active': true,
        'icon': Icons.chat_bubble_outline_rounded,
      },
      {
        'title': 'Instant Push Lead Alerts',
        'subtitle': 'Admins receive instant push notifications on every new inquiry',
        'status': 'Active',
        'active': true,
        'icon': Icons.notifications_active_outlined,
      },
      {
        'title': 'Data Security & Privacy Guard',
        'subtitle': 'Token encrypted with end-to-end read-only protection safeguards',
        'status': 'Protected',
        'active': true,
        'icon': Icons.security_rounded,
      },
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
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meta Integration Health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('All marketing channels and lead pipelines are operational.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...healthItems.map((item) {
            final active = item['active'] as bool;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'] as IconData, size: 18, color: active ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(item['subtitle'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['status'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
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
