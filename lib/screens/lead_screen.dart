import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/lead_card.dart';
import '../widgets/skeleton_loading.dart';
import 'add_lead_screen.dart';

class LeadsScreen extends StatefulWidget {
  final List<Lead> leads;
  final bool isLoading;
  final ValueChanged<int>? onNavigationChanged;
  final UserModel? currentUser;
  final Function(Lead)? onLeadUpdated;
  final Function(Lead)? onLeadAdded;
  final VoidCallback? onOpenAllotment;

  const LeadsScreen({
    super.key,
    required this.leads,
    this.isLoading = false,
    this.onNavigationChanged,
    this.currentUser,
    this.onLeadUpdated,
    this.onLeadAdded,
    this.onOpenAllotment,
  });

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final searchController = TextEditingController();

  String searchQuery = '';
  LeadStatus? selectedStatus;
  String? selectedSourceFilter;
  String? selectedCategoryFilter;
  String selectedSort = 'date_desc';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Lead> get filteredLeads {
    final list = widget.leads.where((lead) {
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

  int get unassignedCount =>
      widget.leads.where((l) => l.assignedTo.trim().isEmpty).length;

  @override
  Widget build(BuildContext context) {
    final leads = filteredLeads;
    final isAdmin = widget.currentUser?.isAdmin ?? true;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        actionsPadding: const EdgeInsets.only(right: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'All Leads' : 'My Leads',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              isAdmin
                  ? '${widget.leads.length} total company leads'
                  : 'Assigned to ${widget.currentUser?.name ?? "you"}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (isAdmin && widget.onOpenAllotment != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: widget.onOpenAllotment,
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: Text(
                  unassignedCount > 0 ? 'Allot ($unassignedCount)' : 'Allot',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: unassignedCount > 0
                      ? const Color(0xFFDC2626)
                      : AppTheme.primary,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Add New Lead',
            onPressed: _openAddLeadScreen,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            tooltip: 'Sort & Filter Leads',
            onPressed: _showSortAndFilterModal,
            icon: Badge(
              isLabelVisible: selectedSort != 'date_desc' ||
                  selectedCategoryFilter != null ||
                  selectedStatus != null ||
                  selectedSourceFilter != null,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Role context banner
          if (isAdmin && unassignedCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$unassignedCount leads unassigned to executives',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  if (widget.onOpenAllotment != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        minimumSize: const Size(70, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: widget.onOpenAllotment,
                      child: const Text('Allot', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            )
          else if (!isAdmin)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Viewing leads allotted to ${widget.currentUser?.name} (${widget.leads.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search leads...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),

          _buildFilters(),

          const SizedBox(height: 5),

          Expanded(
            child: widget.isLoading
                ? const LeadsScreenSkeleton()
                : leads.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: leads.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LeadCard(
                              lead: leads[index],
                              currentUser: widget.currentUser,
                              onLeadUpdated: widget.onLeadUpdated,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddLeadScreen,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Lead',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
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

  Future<void> _openAddLeadScreen() async {
    final newLead = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(
          currentUser: widget.currentUser ?? UserModel.admin,
          onLeadAdded: (lead) {
            widget.onLeadAdded?.call(lead);
            if (mounted) setState(() {});
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
                          _modalCategoryChip('💼 Salary / Personal', 'salary', setModalState),
                          _modalCategoryChip('🏠 Home Loan', 'home', setModalState),
                          _modalCategoryChip('🏢 Business Loan', 'business', setModalState),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'LEAD STATUS',
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
                          _modalStatusChip('All', null, setModalState),
                          _modalStatusChip('New', LeadStatus.newLead, setModalState),
                          _modalStatusChip('Contacted', LeadStatus.contacted, setModalState),
                          _modalStatusChip('Qualified', LeadStatus.qualified, setModalState),
                          _modalStatusChip('In Process', LeadStatus.converted, setModalState),
                          _modalStatusChip('Rejected', LeadStatus.lost, setModalState),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: Text(
                            'Apply (${filteredLeads.length} Leads)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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

  Widget _modalSortChip(String label, String key, StateSetter setModalState) {
    final isSelected = selectedSort == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setModalState(() => selectedSort = key);
          setState(() => selectedSort = key);
        }
      },
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
    );
  }

  Widget _modalCategoryChip(String label, String? key, StateSetter setModalState) {
    final isSelected = selectedCategoryFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setModalState(() => selectedCategoryFilter = key);
        setState(() => selectedCategoryFilter = key);
      },
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
    );
  }

  Widget _modalStatusChip(String label, LeadStatus? status, StateSetter setModalState) {
    final isSelected = selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setModalState(() => selectedStatus = status);
        setState(() => selectedStatus = status);
      },
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
    );
  }

  Widget _filter(String title, LeadStatus? status) {
    final selected = selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedStatus = status;
          });
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.currentUser?.isSalesExecutive == true
                  ? 'No leads allotted yet'
                  : 'No leads found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.currentUser?.isSalesExecutive == true
                  ? 'Leads will appear here as soon as the Administrator allots them to you.'
                  : 'Try changing your search or filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
