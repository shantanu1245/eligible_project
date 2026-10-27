import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class LeadAllotmentScreen extends StatefulWidget {
  final List<Lead> leads;
  final Function(List<Lead>) onLeadsUpdated;

  const LeadAllotmentScreen({
    super.key,
    required this.leads,
    required this.onLeadsUpdated,
  });

  @override
  State<LeadAllotmentScreen> createState() => _LeadAllotmentScreenState();
}

class _LeadAllotmentScreenState extends State<LeadAllotmentScreen> {
  late List<Lead> _currentLeads;
  String _selectedFilter = 'Unassigned';
  String? _selectedCategoryFilter; // null = All, 'salary', 'home', 'business'
  final Set<String> _selectedLeadIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentLeads = List.from(widget.leads);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Lead> get _filteredLeads {
    return _currentLeads.where((lead) {
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          lead.name.toLowerCase().contains(query) ||
          lead.phone.toLowerCase().contains(query) ||
          lead.email.toLowerCase().contains(query) ||
          lead.source.toLowerCase().contains(query) ||
          lead.categoryDisplay.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_selectedFilter == 'Unassigned') {
        matchesFilter = lead.assignedTo.trim().isEmpty;
      } else if (_selectedFilter == 'Amit Patil') {
        matchesFilter = lead.assignedTo.toLowerCase().contains('amit');
      } else if (_selectedFilter == 'Priya Shah') {
        matchesFilter = lead.assignedTo.toLowerCase().contains('priya');
      }

      final matchesCategory = _selectedCategoryFilter == null ||
          lead.categoryKey == _selectedCategoryFilter;

      return matchesSearch && matchesFilter && matchesCategory;
    }).toList();
  }

  int get _unassignedCount =>
      _currentLeads.where((l) => l.assignedTo.trim().isEmpty).length;
  int get _amitCount => _currentLeads
      .where((l) => l.assignedTo.toLowerCase().contains('amit'))
      .length;
  int get _priyaCount => _currentLeads
      .where((l) => l.assignedTo.toLowerCase().contains('priya'))
      .length;

  int _categoryCount(String key) =>
      _currentLeads.where((l) => l.categoryKey == key).length;

  int _categoryUnassignedCount(String key) => _currentLeads
      .where((l) => l.assignedTo.trim().isEmpty && l.categoryKey == key)
      .length;

  void _allotCategoryBatch(String categoryKey, UserModel executive) {
    final targets = _currentLeads
        .where((l) => l.assignedTo.trim().isEmpty && l.categoryKey == categoryKey)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No unassigned leads found in this category.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    final targetIds = targets.map((l) => l.id).toSet();

    setState(() {
      for (int i = 0; i < _currentLeads.length; i++) {
        if (targetIds.contains(_currentLeads[i].id)) {
          _currentLeads[i] =
              _currentLeads[i].copyWith(assignedTo: executive.name);
        }
      }
      _selectedLeadIds.removeAll(targetIds);
    });

    widget.onLeadsUpdated(_currentLeads);

    for (final lead in targets) {
      BackendService().allotLead(lead.id, assignedTo: executive.name);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${targets.length} ${targets.first.categoryDisplay} leads allotted to ${executive.name}',
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _allotSingleLead(Lead lead, UserModel executive) {
    final updatedLead = lead.copyWith(assignedTo: executive.name);
    final index = _currentLeads.indexWhere((l) => l.id == lead.id);
    if (index != -1) {
      setState(() {
        _currentLeads[index] = updatedLead;
        _selectedLeadIds.remove(lead.id);
      });
      widget.onLeadsUpdated(_currentLeads);

      // Trigger targeted notification to this executive's devices
      BackendService().allotLead(lead.id, assignedTo: executive.name);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lead "${lead.name}" allotted to ${executive.name} (Notification sent to their devices)'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _allotBulkLeads(UserModel executive) {
    if (_selectedLeadIds.isEmpty) return;

    final count = _selectedLeadIds.length;
    final idsToAllot = List<String>.from(_selectedLeadIds);

    setState(() {
      for (int i = 0; i < _currentLeads.length; i++) {
        if (_selectedLeadIds.contains(_currentLeads[i].id)) {
          _currentLeads[i] =
              _currentLeads[i].copyWith(assignedTo: executive.name);
        }
      }
      _selectedLeadIds.clear();
    });

    widget.onLeadsUpdated(_currentLeads);

    // Trigger targeted backend allotment notifications
    for (final id in idsToAllot) {
      BackendService().allotLead(id, assignedTo: executive.name);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count leads allotted to ${executive.name} (Alert sent to their logged-in devices)'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAllotmentBottomSheet(Lead lead) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Allot Lead: ${lead.name}',
                      style: const TextStyle(
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
                const SizedBox(height: 6),
                const Text(
                  'Select a Sales Executive to handle this lead:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ...UserModel.salesExecutives.map((exec) {
                  final isCurrentlyAssigned =
                      lead.assignedTo.toLowerCase().contains(exec.name.toLowerCase().split(' ').first);
                  final execCount = _currentLeads
                      .where((l) => l.assignedTo.toLowerCase().contains(exec.name.toLowerCase().split(' ').first))
                      .length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isCurrentlyAssigned
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                      border: Border.all(
                        color: isCurrentlyAssigned
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: isCurrentlyAssigned ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrentlyAssigned
                            ? AppTheme.primary
                            : const Color(0xFFDBEAFE),
                        child: Text(
                          exec.initial,
                          style: TextStyle(
                            color: isCurrentlyAssigned
                                ? Colors.white
                                : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        exec.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '$execCount leads assigned • ${exec.email}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isCurrentlyAssigned
                          ? const Chip(
                              label: Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              backgroundColor: Color(0xFFDBEAFE),
                              padding: EdgeInsets.zero,
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _allotSingleLead(lead, exec);
                              },
                              child: const Text('Assign'),
                            ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBulkAllotmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allot ${_selectedLeadIds.length} Selected Leads',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose which sales executive should receive these leads:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ...UserModel.salesExecutives.map((exec) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          exec.initial,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        exec.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        exec.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(90, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _allotBulkLeads(exec);
                        },
                        child: const Text('Allot All'),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = _filteredLeads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lead Allotment',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              'Distribute leads to sales executives',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton.icon(
              onPressed: _showCategoryBatchAllotmentModal,
              icon: const Icon(Icons.category_rounded, size: 16),
              label: const Text(
                'Category Allot',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
          if (_selectedLeadIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _showBulkAllotmentSheet,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(
                  'Allot (${_selectedLeadIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  backgroundColor: const Color(0xFFDBEAFE),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // KPI Stat cards
          _buildMetricsOverview(),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by lead name, phone or source...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Filter chips
          _buildFilterChips(),

          const Divider(height: 1, color: AppTheme.border),

          // Select all / Bulk action bar
          if (_selectedFilter == 'Unassigned' && leads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectedLeadIds.length == leads.length &&
                        leads.isNotEmpty,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedLeadIds
                              .addAll(leads.map((l) => l.id));
                        } else {
                          _selectedLeadIds.clear();
                        }
                      });
                    },
                  ),
                  Text(
                    _selectedLeadIds.isEmpty
                        ? 'Select unassigned leads for bulk allotment'
                        : '${_selectedLeadIds.length} leads selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedLeadIds.isNotEmpty
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selectedLeadIds.isNotEmpty
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Lead list
          Expanded(
            child: leads.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: leads.length,
                    itemBuilder: (context, index) {
                      final lead = leads[index];
                      final isSelected = _selectedLeadIds.contains(lead.id);

                      return _buildLeadAllotmentCard(lead, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              label: 'Unassigned',
              value: '$_unassignedCount',
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              isAlert: _unassignedCount > 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Amit Patil',
              value: '$_amitCount',
              color: AppTheme.primary,
              bgColor: const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              label: 'Priya Shah',
              value: '$_priyaCount',
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? color.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Unassigned', 'count': _unassignedCount},
      {'label': 'All', 'count': _currentLeads.length},
      {'label': 'Amit Patil', 'count': _amitCount},
      {'label': 'Priya Shah', 'count': _priyaCount},
    ];

    final categories = [
      {'label': 'All Categories', 'key': null, 'count': _currentLeads.length},
      {'label': '💼 Salary / Personal', 'key': 'salary', 'count': _categoryCount('salary')},
      {'label': '🏠 Home Loan', 'key': 'home', 'count': _categoryCount('home')},
      {'label': '🏢 Business Loan', 'key': 'business', 'count': _categoryCount('business')},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive / status filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilter == f['label'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${f['label']} (${f['count']})'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = f['label'] as String;
                      _selectedLeadIds.clear();
                    });
                  },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Loan Category Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: categories.map((c) {
              final isSelected = _selectedCategoryFilter == c['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${c['label']} (${c['count']})'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategoryFilter = c['key'] as String?;
                      _selectedLeadIds.clear();
                    });
                  },
                  selectedColor: const Color(0xFFDBEAFE),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF1D4ED8) : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : AppTheme.border,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _showCategoryBatchAllotmentModal() {
    String selectedCatKey = 'salary';
    UserModel selectedExec = UserModel.salesExecutives.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final unassignedSalary = _categoryUnassignedCount('salary');
            final unassignedHome = _categoryUnassignedCount('home');
            final unassignedBusiness = _categoryUnassignedCount('business');

            final categoryList = [
              {
                'key': 'salary',
                'title': '💼 Salary / Personal Loan',
                'unassigned': unassignedSalary,
                'total': _categoryCount('salary'),
              },
              {
                'key': 'home',
                'title': '🏠 Home Loan',
                'unassigned': unassignedHome,
                'total': _categoryCount('home'),
              },
              {
                'key': 'business',
                'title': '🏢 Business Loan',
                'unassigned': unassignedBusiness,
                'total': _categoryCount('business'),
              },
            ];

            final selectedCategoryInfo =
                categoryList.firstWhere((c) => c['key'] == selectedCatKey);
            final targetCount = selectedCategoryInfo['unassigned'] as int;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Category-Wise Allotment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Allot unassigned leads of a specific website loan type to an executive in one tap:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '1. SELECT LOAN CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...categoryList.map((cat) {
                      final isSelected = selectedCatKey == cat['key'];
                      final unassigned = cat['unassigned'] as int;
                      final total = cat['total'] as int;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: cat['key'] as String,
                          groupValue: selectedCatKey,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedCatKey = val);
                            }
                          },
                          title: Text(
                            cat['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '$unassigned unassigned of $total leads',
                            style: TextStyle(
                              fontSize: 12,
                              color: unassigned > 0
                                  ? const Color(0xFFDC2626)
                                  : AppTheme.textSecondary,
                              fontWeight: unassigned > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text(
                      '2. SELECT SALES EXECUTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: UserModel.salesExecutives.map((exec) {
                        final isExecSelected = selectedExec.id == exec.id;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => selectedExec = exec);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isExecSelected
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isExecSelected
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: isExecSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isExecSelected
                                        ? AppTheme.primary
                                        : const Color(0xFFDBEAFE),
                                    child: Text(
                                      exec.initial,
                                      style: TextStyle(
                                        color: isExecSelected
                                            ? Colors.white
                                            : AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    exec.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: targetCount > 0
                              ? AppTheme.primary
                              : Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: targetCount == 0
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _allotCategoryBatch(selectedCatKey, selectedExec);
                              },
                        icon: const Icon(Icons.assignment_turned_in, size: 18),
                        label: Text(
                          targetCount > 0
                              ? 'Allot $targetCount Leads to ${selectedExec.name}'
                              : 'No Unassigned Leads',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeadAllotmentCard(Lead lead, bool isSelected) {
    final isUnassigned = lead.assignedTo.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : isUnassigned
                  ? const Color(0xFFFECACA)
                  : AppTheme.border,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_selectedFilter == 'Unassigned')
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedLeadIds.add(lead.id);
                        } else {
                          _selectedLeadIds.remove(lead.id);
                        }
                      });
                    },
                  ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isUnassigned
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFEFF6FF),
                  child: Text(
                    lead.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isUnassigned
                          ? const Color(0xFFDC2626)
                          : AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            lead.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (lead.city != null && lead.city!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.location_on_outlined,
                                size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 2),
                            Text(
                              lead.city!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Allot button
                ElevatedButton.icon(
                  onPressed: () => _showAllotmentBottomSheet(lead),
                  icon: Icon(
                    isUnassigned ? Icons.person_add : Icons.swap_horiz,
                    size: 15,
                  ),
                  label: Text(
                    isUnassigned ? 'Allot' : 'Reassign',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnassigned
                        ? const Color(0xFFDC2626)
                        : AppTheme.primary,
                    minimumSize: const Size(75, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              children: [
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    lead.categoryDisplay,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                if (lead.requiredLoan != null && lead.requiredLoan! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      '₹${lead.requiredLoan! >= 100000 ? "${(lead.requiredLoan! / 100000).toStringAsFixed(1)}L" : lead.requiredLoan!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Assigned to status chip
                Row(
                  children: [
                    const Text(
                      'Assigned: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUnassigned
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUnassigned ? 'Unassigned' : lead.assignedTo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isUnassigned
                              ? const Color(0xFFDC2626)
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.done_all_rounded,
              size: 32,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Leads Match Filter',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedFilter == 'Unassigned'
                ? 'All leads have been allotted to sales executives!'
                : 'No leads found for this criteria.',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
