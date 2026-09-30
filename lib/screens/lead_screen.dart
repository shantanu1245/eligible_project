import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/lead_card.dart';
import 'add_lead_screen.dart';

class LeadsScreen extends StatefulWidget {
  final List<Lead> leads;
  final ValueChanged<int>? onNavigationChanged;
  final UserModel? currentUser;
  final Function(Lead)? onLeadUpdated;
  final Function(Lead)? onLeadAdded;
  final VoidCallback? onOpenAllotment;

  const LeadsScreen({
    super.key,
    required this.leads,
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Lead> get filteredLeads {
    return widget.leads.where((lead) {
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          lead.name.toLowerCase().contains(query) ||
          lead.phone.toLowerCase().contains(query) ||
          lead.email.toLowerCase().contains(query) ||
          lead.source.toLowerCase().contains(query);

      final matchesStatus =
          selectedStatus == null || lead.status == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'All Leads' : 'My Leads',
              style: const TextStyle(
                fontSize: 20,
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
            TextButton.icon(
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
          IconButton(
            tooltip: 'Add New Lead',
            onPressed: _openAddLeadScreen,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
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
            child: leads.isEmpty
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
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filter('All', null),
          _filter('New', LeadStatus.newLead),
          _filter('Contacted', LeadStatus.contacted),
          _filter('Qualified', LeadStatus.qualified),
          _filter('Converted', LeadStatus.converted),
        ],
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
