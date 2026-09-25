import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/lead_card.dart';

class LeadsScreen extends StatefulWidget {
  final List<Lead> leads;
  final ValueChanged<int>? onNavigationChanged;

  const LeadsScreen({
    super.key,
    required this.leads,
    this.onNavigationChanged,
  });

  @override
  State<LeadsScreen> createState() =>
      _LeadsScreenState();
}

class _LeadsScreenState
    extends State<LeadsScreen> {
  final searchController =
      TextEditingController();

  String searchQuery = '';
  LeadStatus? selectedStatus;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Lead> get filteredLeads {
    return widget.leads.where((lead) {
      final query =
          searchQuery.toLowerCase().trim();

      final matchesSearch =
          query.isEmpty ||
          lead.name
              .toLowerCase()
              .contains(query) ||
          lead.phone
              .toLowerCase()
              .contains(query) ||
          lead.email
              .toLowerCase()
              .contains(query);

      final matchesStatus =
          selectedStatus == null ||
          lead.status == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leads = filteredLeads;

    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        title: const Text(
          'Leads',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.tune_rounded,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              10,
            ),

            child: TextField(
              controller: searchController,

              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },

              decoration:
                  const InputDecoration(
                hintText:
                    'Search leads...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                ),
              ),
            ),
          ),

          _buildFilters(),

          const SizedBox(height: 5),

          Expanded(
            child: leads.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      100,
                    ),

                    itemCount: leads.length,

                    itemBuilder:
                        (context, index) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),

                        child: LeadCard(
                          lead: leads[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,

        icon: const Icon(
          Icons.add,
        ),

        label: const Text(
          'Add Lead',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      bottomNavigationBar:
          AppBottomNavigation(
        currentIndex: 1,
        onChanged: (index) {
          widget.onNavigationChanged
              ?.call(index);
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 42,

      child: ListView(
        scrollDirection: Axis.horizontal,

        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
        ),

        children: [
          _filter(
            'All',
            null,
          ),

          _filter(
            'New',
            LeadStatus.newLead,
          ),

          _filter(
            'Contacted',
            LeadStatus.contacted,
          ),

          _filter(
            'Qualified',
            LeadStatus.qualified,
          ),

          _filter(
            'Converted',
            LeadStatus.converted,
          ),
        ],
      ),
    );
  }

  Widget _filter(
    String title,
    LeadStatus? status,
  ) {
    final selected =
        selectedStatus == status;

    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),

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

          color: selected
              ? Colors.white
              : AppTheme.textSecondary,
        ),

        selectedColor:
            AppTheme.primary,

        backgroundColor: Colors.white,

        side: BorderSide(
          color: selected
              ? AppTheme.primary
              : AppTheme.border,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              height: 70,
              width: 70,

              decoration: BoxDecoration(
                color:
                    const Color(0xFFEFF6FF),
                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AppTheme.primary,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No leads found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Try changing your search or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
