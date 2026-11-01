import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/skeleton_loading.dart';
import 'add_lead_screen.dart';
import 'lead_detail.dart';
import 'recycle_bin_screen.dart';

class LeadsScreen extends StatefulWidget {
  final List<Lead> leads;
  final bool isLoading;
  final ValueChanged<int>? onNavigationChanged;
  final UserModel? currentUser;
  final Function(Lead)? onLeadUpdated;
  final Function(Lead)? onLeadAdded;
  final Function(List<String>)? onLeadsDeleted;
  final VoidCallback? onOpenAllotment;

  const LeadsScreen({
    super.key,
    required this.leads,
    this.isLoading = false,
    this.onNavigationChanged,
    this.currentUser,
    this.onLeadUpdated,
    this.onLeadAdded,
    this.onLeadsDeleted,
    this.onOpenAllotment,
  });

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final searchController = TextEditingController();

  late List<Lead> _localLeads;
  String searchQuery = '';
  LeadStatus? selectedStatus;
  String? selectedSourceFilter;
  String? selectedCategoryFilter;
  String selectedSort = 'date_desc';

  // Multi-selection state for bulk delete
  bool isSelectionMode = false;
  final Set<String> selectedLeadIds = {};

  @override
  void initState() {
    super.initState();
    _localLeads = List.from(widget.leads);
  }

  @override
  void didUpdateWidget(covariant LeadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads != widget.leads) {
      _localLeads = List.from(widget.leads);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Lead> get filteredLeads {
    final list = _localLeads.where((lead) {
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          lead.name.toLowerCase().contains(query) ||
          lead.phone.toLowerCase().contains(query) ||
          lead.email.toLowerCase().contains(query) ||
          lead.source.toLowerCase().contains(query) ||
          lead.campaign.toLowerCase().contains(query) ||
          lead.categoryDisplay.toLowerCase().contains(query);

      final matchesStatus =
          selectedStatus == null || lead.status == selectedStatus;

      final matchesSource = selectedSourceFilter == null ||
          (selectedSourceFilter == 'whatsapp' &&
              (lead.campaign.toLowerCase().contains('whatsapp') ||
                  lead.campaign.toLowerCase().contains("what's app") ||
                  lead.source.toLowerCase().contains('whatsapp') ||
                  lead.source.toLowerCase().contains('meta'))) ||
          (selectedSourceFilter == 'calculator' &&
              lead.source.toLowerCase().contains('calculator'));

      final matchesCategory = selectedCategoryFilter == null ||
          lead.categoryKey == selectedCategoryFilter;

      return matchesSearch && matchesStatus && matchesSource && matchesCategory;
    }).toList();

    list.sort((a, b) {
      switch (selectedSort) {
        case 'category_asc':
          final catComp = a.categoryDisplay.compareTo(b.categoryDisplay);
          if (catComp != 0) return catComp;
          return b.createdAt.compareTo(a.createdAt);
        case 'date_asc':
          return a.createdAt.compareTo(b.createdAt);
        case 'amount_desc':
          final amtA = a.requiredLoan ?? a.propertyCost ?? a.annualTurnover ?? 0.0;
          final amtB = b.requiredLoan ?? b.propertyCost ?? b.annualTurnover ?? 0.0;
          return amtB.compareTo(amtA);
        case 'amount_asc':
          final amtA = a.requiredLoan ?? a.propertyCost ?? a.annualTurnover ?? 0.0;
          final amtB = b.requiredLoan ?? b.propertyCost ?? b.annualTurnover ?? 0.0;
          return amtA.compareTo(amtB);
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'date_desc':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  bool get _isAdmin => widget.currentUser?.isAdmin ?? true;

  void _toggleLeadSelection(String id) {
    setState(() {
      if (selectedLeadIds.contains(id)) {
        selectedLeadIds.remove(id);
        if (selectedLeadIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedLeadIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Lead> leads) {
    setState(() {
      final allFilteredIds = leads.map((l) => l.id).toSet();
      if (selectedLeadIds.containsAll(allFilteredIds)) {
        selectedLeadIds.removeAll(allFilteredIds);
        if (selectedLeadIds.isEmpty) isSelectionMode = false;
      } else {
        selectedLeadIds.addAll(allFilteredIds);
      }
    });
  }

  Future<void> _openLeadDetail(Lead lead) async {
    final updated = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(
          lead: lead,
          currentUser: widget.currentUser,
          onLeadUpdated: (u) {
            widget.onLeadUpdated?.call(u);
            setState(() {
              final idx = _localLeads.indexWhere((l) => l.id == u.id);
              if (idx != -1) _localLeads[idx] = u;
            });
          },
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _localLeads.indexWhere((l) => l.id == updated.id);
        if (idx != -1) _localLeads[idx] = updated;
      });
    }
  }

  Future<void> _confirmDeleteSingleLead(Lead lead) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Move to Recycle Bin'),
          ],
        ),
        content: Text(
          'Move "${lead.name}" to the Recycle Bin?\n\nIt will be kept for 30 days before permanent deletion. You can restore it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final leadJson = lead.toJson();
      final leadId = lead.id;
      final leadName = lead.name;
      setState(() {
        _localLeads.removeWhere((l) => l.id == leadId);
        selectedLeadIds.remove(leadId);
      });

      widget.onLeadsDeleted?.call([leadId]);
      await BackendService().deleteLead(
        leadId,
        leadData: leadJson,
        deletedBy: widget.currentUser?.name ?? 'Admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Moved "$leadName" to Recycle Bin (kept for 30 days)'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmBulkDelete() async {
    final count = selectedLeadIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Move $count Leads to Bin?'),
          ],
        ),
        content: Text(
          'Move $count selected leads to the Recycle Bin?\n\nThey will be safely kept for 30 days before permanent deletion. You can restore them anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Move $count to Bin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final idsToDelete = selectedLeadIds.toList();
      final idSet = idsToDelete.toSet();
      final targets = _localLeads.where((l) => idSet.contains(l.id)).toList();
      final leadsData = targets.map((l) => l.toJson()).toList();

      setState(() {
        _localLeads.removeWhere((l) => idSet.contains(l.id));
        selectedLeadIds.clear();
        isSelectionMode = false;
      });

      widget.onLeadsDeleted?.call(idsToDelete);
      await BackendService().deleteLeadsBulk(
        idsToDelete,
        leadsData: leadsData,
        deletedBy: widget.currentUser?.name ?? 'Admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Moved ${idsToDelete.length} leads to Recycle Bin (kept for 30 days)'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCategoryDeleteDialog() {
    final salaryCount = _localLeads.where((l) => l.categoryKey == 'salary').length;
    final homeCount = _localLeads.where((l) => l.categoryKey == 'home').length;
    final businessCount = _localLeads.where((l) => l.categoryKey == 'business').length;
    final otherCount = _localLeads.where((l) => l.categoryKey != 'salary' && l.categoryKey != 'home' && l.categoryKey != 'business').length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Delete Leads Category-Wise',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a loan category to delete all corresponding leads permanently:',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                _buildCategoryDeleteRow(
                  emoji: '💼',
                  title: 'Salaried Personal Loan',
                  categoryKey: 'salary',
                  count: salaryCount,
                  sheetContext: ctx,
                ),
                _buildCategoryDeleteRow(
                  emoji: '🏠',
                  title: 'Home Loan / Mortgage',
                  categoryKey: 'home',
                  count: homeCount,
                  sheetContext: ctx,
                ),
                _buildCategoryDeleteRow(
                  emoji: '🏢',
                  title: 'Business / MSME Loan',
                  categoryKey: 'business',
                  count: businessCount,
                  sheetContext: ctx,
                ),
                if (otherCount > 0)
                  _buildCategoryDeleteRow(
                    emoji: '📋',
                    title: 'Other / General Leads',
                    categoryKey: 'other',
                    count: otherCount,
                    sheetContext: ctx,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryDeleteRow({
    required String emoji,
    required String title,
    required String categoryKey,
    required int count,
    required BuildContext sheetContext,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$count leads available',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > 0 ? AppTheme.textSecondary : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: count == 0
                ? null
                : () {
                    Navigator.pop(sheetContext);
                    _confirmDeleteCategory(categoryKey, title, count);
                  },
            icon: const Icon(Icons.delete_outline, size: 15),
            label: const Text('Delete All', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String key, String title, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Move $count $title Leads to Bin?'),
          ],
        ),
        content: Text(
          'Move all $count $title leads to the Recycle Bin?\n\nThey will be safely kept for 30 days before permanent deletion. You can restore them anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Move $count to Bin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final targets = _localLeads.where((l) {
        if (key == 'salary') return l.categoryKey == 'salary';
        if (key == 'home') return l.categoryKey == 'home';
        if (key == 'business') return l.categoryKey == 'business';
        return l.categoryKey != 'salary' && l.categoryKey != 'home' && l.categoryKey != 'business';
      }).toList();

      final deletedIds = targets.map((l) => l.id).toList();
      final categoryLeads = targets.map((l) => l.toJson()).toList();

      setState(() {
        final idSet = deletedIds.toSet();
        _localLeads.removeWhere((l) => idSet.contains(l.id));
        selectedLeadIds.removeAll(idSet);
      });

      widget.onLeadsDeleted?.call(deletedIds);
      await BackendService().deleteLeadsByCategory(
        key,
        categoryLeads: categoryLeads,
        deletedBy: widget.currentUser?.name ?? 'Admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Moved ${deletedIds.length} $title leads to Recycle Bin (kept for 30 days)'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openRecycleBin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecycleBinScreen(
          currentUser: widget.currentUser,
          onLeadRestored: (restoredLead) {
            setState(() {
              _localLeads.insert(0, restoredLead);
            });
            widget.onLeadAdded?.call(restoredLead);
          },
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = clean.startsWith('91') ? clean : '91$clean';
    final text = 'Hello $name, contacting you regarding your loan enquiry at Eligible CRM.';
    final uri = Uri.parse('https://wa.me/$formatted?text=${Uri.encodeComponent(text)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final leads = filteredLeads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: isSelectionMode
          // ── MULTI-SELECTION APP BAR ──
          ? AppBar(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedLeadIds.clear();
                  });
                },
              ),
              title: Text(
                '${selectedLeadIds.length} Selected',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  tooltip: 'Select All',
                  icon: const Icon(Icons.select_all_rounded),
                  onPressed: () => _toggleSelectAll(leads),
                ),
                IconButton(
                  tooltip: 'Delete Selected',
                  icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFCA5A5)),
                  onPressed: selectedLeadIds.isEmpty ? null : _confirmBulkDelete,
                ),
              ],
            )
          // ── STANDARD APP BAR ──
          : AppBar(
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin ? 'All Leads' : 'My Leads',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _isAdmin
                        ? '${_localLeads.length} total company leads'
                        : 'Assigned to ${widget.currentUser?.name ?? "you"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                if (_isAdmin)
                  IconButton(
                    tooltip: 'Recycle Bin',
                    icon: const Icon(Icons.auto_delete_outlined, color: Color(0xFFD97706)),
                    onPressed: _openRecycleBin,
                  ),
                IconButton(
                  tooltip: 'Add New Lead',
                  onPressed: _openAddLeadScreen,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
                if (_isAdmin)
                  IconButton(
                    tooltip: 'Select Leads',
                    icon: const Icon(Icons.checklist_rounded),
                    onPressed: () {
                      setState(() {
                        isSelectionMode = true;
                      });
                    },
                  ),
                if (_isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Lead Options',
                    onSelected: (val) {
                      if (val == 'recycle_bin') {
                        _openRecycleBin();
                      } else if (val == 'select_delete') {
                        setState(() => isSelectionMode = true);
                      } else if (val == 'category_delete') {
                        _showCategoryDeleteDialog();
                      } else if (val == 'allot' && widget.onOpenAllotment != null) {
                        widget.onOpenAllotment!();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'recycle_bin',
                        child: Row(
                          children: [
                            Icon(Icons.auto_delete_outlined, size: 18, color: Color(0xFFD97706)),
                            SizedBox(width: 10),
                            Text('Recycle Bin (30 Days)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'select_delete',
                        child: Row(
                          children: [
                            Icon(Icons.checklist, size: 18),
                            SizedBox(width: 10),
                            Text('Bulk Delete Leads'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'category_delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, size: 18, color: Color(0xFFDC2626)),
                            SizedBox(width: 10),
                            Text('Delete Category-Wise', style: TextStyle(color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                      if (widget.onOpenAllotment != null) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'allot',
                          child: Row(
                            children: [
                              Icon(Icons.assignment_ind, size: 18, color: Color(0xFF1877F2)),
                              SizedBox(width: 10),
                              Text('Open Allotment Screen'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
      body: Column(
        children: [
          // ── Search bar & Filter row (filter icon directly in search row) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by customer name, phone, loan...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: (selectedSort != 'date_desc' ||
                            selectedCategoryFilter != null ||
                            selectedStatus != null ||
                            selectedSourceFilter != null)
                        ? const Color(0xFFEFF6FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (selectedSort != 'date_desc' ||
                              selectedCategoryFilter != null ||
                              selectedStatus != null ||
                              selectedSourceFilter != null)
                          ? const Color(0xFF1877F2)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Sort & Filter Leads',
                    onPressed: _showSortAndFilterModal,
                    icon: Badge(
                      isLabelVisible: selectedSort != 'date_desc' ||
                          selectedCategoryFilter != null ||
                          selectedStatus != null ||
                          selectedSourceFilter != null,
                      child: Icon(
                        Icons.tune_rounded,
                        size: 21,
                        color: (selectedSort != 'date_desc' ||
                                selectedCategoryFilter != null ||
                                selectedStatus != null ||
                                selectedSourceFilter != null)
                            ? const Color(0xFF1877F2)
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filters row
          _buildFilters(),

          const SizedBox(height: 4),

          // ── STREAMLINED LEADS LIST VIEW ──
          Expanded(
            child: widget.isLoading
                ? const LeadsScreenSkeleton()
                : leads.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 90),
                        itemCount: leads.length,
                        itemBuilder: (context, index) {
                          final lead = leads[index];
                          final isSelected = selectedLeadIds.contains(lead.id);
                          return _buildLeadListTile(lead, isSelected);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: selectedLeadIds.isEmpty ? null : _confirmBulkDelete,
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.delete_forever),
              label: Text('Delete (${selectedLeadIds.length})'),
            )
          : FloatingActionButton.extended(
              onPressed: _openAddLeadScreen,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Lead',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 1,
        onChanged: (index) {
          widget.onNavigationChanged?.call(index);
        },
      ),
    );
  }

  // ── CLEAN LIST VIEW ITEM ──
  Widget _buildLeadListTile(Lead lead, bool isSelected) {
    final isWhatsApp = lead.source.toLowerCase().contains('whatsapp') ||
        lead.campaign.toLowerCase().contains('whatsapp') ||
        lead.campaign.toLowerCase().contains("what's app");

    final isUnassigned = lead.assignedTo.trim().isEmpty ||
        lead.assignedTo.toLowerCase() == 'unassigned' ||
        lead.assignedTo.toLowerCase() == 'available for claim';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1877F2)
              : (isWhatsApp ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isSelectionMode) {
            _toggleLeadSelection(lead.id);
          } else {
            _openLeadDetail(lead);
          }
        },
        onLongPress: () {
          if (!isSelectionMode && _isAdmin) {
            setState(() {
              isSelectionMode = true;
              selectedLeadIds.add(lead.id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Selection Checkbox (only in multi-selection mode)
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF1877F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleLeadSelection(lead.id),
                  ),
                ),

              // Lead information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lead.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusChip(lead.status),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Category tag & Loan Amount
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _categoryBgColor(lead.categoryKey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lead.categoryDisplay,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _categoryTextColor(lead.categoryKey),
                            ),
                          ),
                        ),
                        if (lead.requiredLoan != null && lead.requiredLoan! > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatLoanAmount(lead.requiredLoan!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Phone & Assignee
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          lead.phone,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          isUnassigned ? Icons.warning_amber_rounded : Icons.person_outline,
                          size: 12,
                          color: isUnassigned ? const Color(0xFFDC2626) : AppTheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            isUnassigned ? 'Unassigned' : lead.assignedTo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isUnassigned ? const Color(0xFFDC2626) : AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Trailing actions: Popup menu or chevron
              if (!isSelectionMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'details') _openLeadDetail(lead);
                        if (val == 'delete') _confirmDeleteSingleLead(lead);
                        if (val == 'whatsapp') _openWhatsApp(lead.phone, lead.name);
                        if (val == 'call') _callPhone(lead.phone);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new, size: 16),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'whatsapp',
                          child: Row(
                            children: [
                              Icon(Icons.chat, size: 16, color: Color(0xFF16A34A)),
                              SizedBox(width: 8),
                              Text('WhatsApp'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'call',
                          child: Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Call'),
                            ],
                          ),
                        ),
                        if (_isAdmin) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text('Delete Lead', style: TextStyle(color: Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(LeadStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case LeadStatus.newLead:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        label = 'New';
        break;
      case LeadStatus.contacted:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Contacted';
        break;
      case LeadStatus.qualified:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'Qualified';
        break;
      case LeadStatus.converted:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Converted';
        break;
      case LeadStatus.lost:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatLoanAmount(double val) {
    if (val >= 10000000) {
      return '₹${(val / 10000000).toStringAsFixed(2)} Cr';
    } else if (val >= 100000) {
      return '₹${(val / 100000).toStringAsFixed(1)} Lakh';
    }
    return '₹${val.toInt()}';
  }

  Color _categoryBgColor(String key) {
    switch (key) {
      case 'salary':
        return const Color(0xFFEFF6FF);
      case 'home':
        return const Color(0xFFFEF3C7);
      case 'business':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _categoryTextColor(String key) {
    switch (key) {
      case 'salary':
        return const Color(0xFF1D4ED8);
      case 'home':
        return const Color(0xFFB45309);
      case 'business':
        return const Color(0xFF7E22CE);
      default:
        return const Color(0xFF475569);
    }
  }

  Future<void> _openAddLeadScreen() async {
    final newLead = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(
          currentUser: widget.currentUser ?? UserModel.admin,
          onLeadAdded: (lead) {
            widget.onLeadAdded?.call(lead);
            setState(() {
              _localLeads.insert(0, lead);
            });
          },
        ),
      ),
    );
    if (newLead != null && mounted) {
      setState(() {});
    }
  }

  Widget _buildFilters() {
    final hasActiveFilter = selectedSort != 'date_desc' ||
        selectedCategoryFilter != null ||
        selectedSourceFilter != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Row
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filter('All', null),
              _filter('New', LeadStatus.newLead),
              _filter('Contacted', LeadStatus.contacted),
              _filter('Qualified', LeadStatus.qualified),
              _filter('In Process', LeadStatus.converted),
              _filter('Rejected', LeadStatus.lost),
            ],
          ),
        ),
        if (hasActiveFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                if (selectedCategoryFilter != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _categoryTitle(selectedCategoryFilter),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => selectedCategoryFilter = null),
                          child: const Icon(Icons.close, size: 13, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (selectedSort != 'date_desc')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _sortLabel(selectedSort),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSort = 'date_desc';
                      selectedCategoryFilter = null;
                      selectedStatus = null;
                      selectedSourceFilter = null;
                    });
                  },
                  child: const Text(
                    'Reset all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _categoryTitle(String? key) {
    switch (key) {
      case 'salary':
        return '💼 Salary / Personal';
      case 'home':
        return '🏠 Home Loan';
      case 'business':
        return '🏢 Business Loan';
      default:
        return 'Category Filter';
    }
  }

  String _sortLabel(String sortKey) {
    switch (sortKey) {
      case 'category_asc':
        return 'Sorted by Category';
      case 'amount_desc':
        return 'Sorted by Loan Amount (High-Low)';
      case 'amount_asc':
        return 'Sorted by Loan Amount (Low-High)';
      case 'date_asc':
        return 'Sorted by Oldest First';
      case 'name_asc':
        return 'Sorted by Name (A-Z)';
      case 'date_desc':
      default:
        return 'Sorted by Newest First';
    }
  }

  void _showSortAndFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sort & Filter Leads',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                selectedSort = 'date_desc';
                                selectedCategoryFilter = null;
                                selectedStatus = null;
                                selectedSourceFilter = null;
                              });
                              setState(() {});
                            },
                            child: const Text('Reset All'),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'SORT LEADS BY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalSortChip('🏷️ Loan Category', 'category_asc', setModalState),
                          _modalSortChip('📅 Newest First', 'date_desc', setModalState),
                          _modalSortChip('📅 Oldest First', 'date_asc', setModalState),
                          _modalSortChip('💰 Amount (High to Low)', 'amount_desc', setModalState),
                          _modalSortChip('💰 Amount (Low to High)', 'amount_asc', setModalState),
                          _modalSortChip('👤 Name (A to Z)', 'name_asc', setModalState),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'LOAN CATEGORY (WEBSITE)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalCategoryChip('All Categories', null, setModalState),
                          _modalCategoryChip('💼 Salaried Personal', 'salary', setModalState),
                          _modalCategoryChip('🏠 Home Loan', 'home', setModalState),
                          _modalCategoryChip('🏢 Business Loan', 'business', setModalState),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'SOURCE PLATFORM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _modalSourceChip('All Sources', null, setModalState),
                          _modalSourceChip('💬 WhatsApp Leads', 'whatsapp', setModalState),
                          _modalSourceChip('🌐 Loan Calculator', 'calculator', setModalState),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Apply Filter',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalSortChip(String label, String value, StateSetter setModalState) {
    final selected = selectedSort == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF1D4ED8) : AppTheme.textPrimary,
      ),
      onSelected: (val) {
        if (val) {
          setModalState(() => selectedSort = value);
          setState(() => selectedSort = value);
        }
      },
    );
  }

  Widget _modalCategoryChip(String label, String? value, StateSetter setModalState) {
    final selected = selectedCategoryFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF1D4ED8) : AppTheme.textPrimary,
      ),
      onSelected: (val) {
        if (val) {
          setModalState(() => selectedCategoryFilter = value);
          setState(() => selectedCategoryFilter = value);
        }
      },
    );
  }

  Widget _modalSourceChip(String label, String? value, StateSetter setModalState) {
    final selected = selectedSourceFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF1D4ED8) : AppTheme.textPrimary,
      ),
      onSelected: (val) {
        if (val) {
          setModalState(() => selectedSourceFilter = value);
          setState(() => selectedSourceFilter = value);
        }
      },
    );
  }

  Widget _filter(String title, LeadStatus? status) {
    final isSelected = selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.border,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (value) {
          setState(() => selectedStatus = status);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isNotEmpty ? 'No leads match "$searchQuery"' : 'No leads found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search terms or filters.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
