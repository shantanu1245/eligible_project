import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_drawer.dart';
import '../widgets/lead_card.dart';
import '../widgets/stat_card.dart';
import 'analytics_screen.dart';
import 'followups_screen.dart';
import 'lead_allotment_screen.dart';
import 'lead_screen.dart';
import 'more_screen.dart';
import '../services/backend_service.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({
    super.key,
    this.user = UserModel.admin,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int currentIndex = 0;
  late List<Lead> leads;

  @override
  void initState() {
    super.initState();
    leads = List.from(_demoLeads);
    _fetchLeadsFromBackend();
  }

  Future<void> _fetchLeadsFromBackend() async {
    final rawList = await BackendService().getLeads();
    if (mounted && rawList.isNotEmpty) {
      setState(() {
        leads = rawList.map((m) => Lead.fromJson(m)).toList();
      });
    }
  }

  void _handleLeadUpdated(Lead updatedLead) {
    final index = leads.indexWhere((l) => l.id == updatedLead.id);
    if (index != -1) {
      setState(() {
        leads[index] = updatedLead;
      });
    }
  }

  void _handleLeadsListUpdated(List<Lead> updatedLeads) {
    setState(() {
      leads = List.from(updatedLeads);
    });
  }

  void _openAllotmentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadAllotmentScreen(
          leads: leads,
          onLeadsUpdated: _handleLeadsListUpdated,
        ),
      ),
    );
  }

  List<Lead> get visibleLeads {
    if (widget.user.isAdmin) {
      return leads;
    }
    // Sales Executive: ONLY leads allotted to this specific executive!
    final nameLower = widget.user.name.toLowerCase();
    final firstName = widget.user.name.split(' ').first.toLowerCase();
    return leads.where((l) {
      final assigned = l.assignedTo.trim().toLowerCase();
      return assigned == nameLower || assigned.contains(firstName);
    }).toList();
  }

  int get unassignedCount =>
      leads.where((l) => l.assignedTo.trim().isEmpty).length;

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------
    // 1. LEADS
    // ------------------------------------------
    if (currentIndex == 1) {
      return LeadsScreen(
        leads: visibleLeads,
        currentUser: widget.user,
        onNavigationChanged: _handleNavigation,
        onLeadUpdated: _handleLeadUpdated,
        onOpenAllotment: widget.user.isAdmin ? _openAllotmentScreen : null,
      );
    }

    // ------------------------------------------
    // 2. FOLLOW-UPS
    // ------------------------------------------
    if (currentIndex == 2) {
      return Scaffold(
        drawer: AppDrawer(
          user: widget.user,
          currentTabIndex: currentIndex,
          onTabSelected: _handleNavigation,
          leads: leads,
          onLeadsUpdated: _handleLeadsListUpdated,
        ),
        body: const FollowupsScreen(),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: currentIndex,
          onChanged: _handleNavigation,
        ),
      );
    }

    // ------------------------------------------
    // 3. ANALYTICS
    // ------------------------------------------
    if (currentIndex == 3) {
      return Scaffold(
        drawer: AppDrawer(
          user: widget.user,
          currentTabIndex: currentIndex,
          onTabSelected: _handleNavigation,
          leads: leads,
          onLeadsUpdated: _handleLeadsListUpdated,
        ),
        body: const AnalyticsScreen(),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: currentIndex,
          onChanged: _handleNavigation,
        ),
      );
    }

    // ------------------------------------------
    // 4. MORE
    // ------------------------------------------
    if (currentIndex == 4) {
      return Scaffold(
        drawer: AppDrawer(
          user: widget.user,
          currentTabIndex: currentIndex,
          onTabSelected: _handleNavigation,
          leads: leads,
          onLeadsUpdated: _handleLeadsListUpdated,
        ),
        body: MoreScreen(
          user: widget.user,
          leads: leads,
          onLeadsUpdated: _handleLeadsListUpdated,
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: currentIndex,
          onChanged: _handleNavigation,
        ),
      );
    }

    // ------------------------------------------
    // 0. DASHBOARD
    // ------------------------------------------
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: AppDrawer(
        user: widget.user,
        currentTabIndex: currentIndex,
        onTabSelected: _handleNavigation,
        leads: leads,
        onLeadsUpdated: _handleLeadsListUpdated,
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(
              Icons.menu_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user.isAdmin ? 'Admin Dashboard' : 'Executive Dashboard',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.user.isAdmin
                  ? 'Overview & lead allotment'
                  : 'Assigned to ${widget.user.name}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // If Admin, quick allotment button with unassigned badge
          if (widget.user.isAdmin)
            IconButton(
              tooltip: 'Lead Allotment ($unassignedCount unassigned)',
              onPressed: _openAllotmentScreen,
              icon: Badge(
                isLabelVisible: unassignedCount > 0,
                label: Text('$unassignedCount'),
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(
                  Icons.assignment_ind_outlined,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

          // Notification button
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(width: 3),

          // User avatar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  currentIndex = 4;
                });
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: widget.user.isAdmin
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFDCFCE7),
                child: Text(
                  widget.user.initial,
                  style: TextStyle(
                    color: widget.user.isAdmin
                        ? AppTheme.primary
                        : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refreshDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Welcome banner
            _buildWelcome(),

            // Administrator Unassigned Leads Allotment Alert Banner
            if (widget.user.isAdmin && unassignedCount > 0)
              _buildAllotmentAlertCard()
            else if (widget.user.isSalesExecutive)
              _buildExecutiveInfoCard(),

            const SizedBox(height: 22),

            // Statistics
            _buildStats(),

            const SizedBox(height: 26),

            // Recent leads header
            _buildSectionHeader(),

            const SizedBox(height: 12),

            // Recent leads (filtered for the logged-in role!)
            if (visibleLeads.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 32, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        widget.user.isSalesExecutive
                            ? 'No leads currently allotted to you.'
                            : 'No leads found.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...visibleLeads.take(4).map(
                (lead) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LeadCard(
                      lead: lead,
                      compact: true,
                      currentUser: widget.user,
                      onLeadUpdated: _handleLeadUpdated,
                    ),
                  );
                },
              ),

            const SizedBox(height: 10),

            // View all button
            _buildViewAllButton(),

            const SizedBox(height: 20),

            // Today's quick summary
            _buildTodaySummary(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: currentIndex,
        onChanged: _handleNavigation,
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _handleNavigation(int index) {
    if (!mounted) return;

    setState(() {
      currentIndex = index;
    });
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshDashboard() async {
    // Temporary refresh logic.
    //
    // Later this will refresh:
    // - Leads
    // - Statistics
    // - Follow-ups
    // - Analytics
    // from your backend/API.

    await Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcome() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),

        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF4F46E5),
          ],

          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF2563EB,
            ).withValues(alpha: 0.15),

            blurRadius: 18,

            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Good evening, ${widget.user.name} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  widget.user.isAdmin
                      ? 'Team overview & lead allocation dashboard.'
                      : 'Here is what is happening with your allotted leads today.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                // Quick action
                GestureDetector(
                  onTap: () {
                    setState(() {
                      currentIndex = 1;
                    });
                  },

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.user.isAdmin
                              ? 'View all leads (${leads.length})'
                              : 'My leads (${visibleLeads.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Decorative icon
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllotmentAlertCard() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_ind_outlined,
              color: Color(0xFFDC2626),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unassignedCount Leads Need Allotment',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Distribute incoming leads to Amit Patil & Priya Shah',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size(76, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _openAllotmentScreen,
            child: const Text('Allot', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveInfoCard() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: Color(0xFF16A34A), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sales Executive Workspace: Viewing ${visibleLeads.length} leads allotted to you.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStats() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final isCompact =
            constraints.maxWidth < 400;

        final aspectRatio =
            isCompact
                ? 1.38
                : 1.5;

        return GridView.count(
          crossAxisCount: 2,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          childAspectRatio:
              aspectRatio,

          shrinkWrap: true,

          physics:
              const NeverScrollableScrollPhysics(),

          children: [
            StatCard(
              title: widget.user.isAdmin ? 'Total Leads' : 'My Leads',
              value: '${visibleLeads.length}',
              change: widget.user.isAdmin ? '+12.5%' : '+15%',
              icon: Icons.people_alt_outlined,
              compactPadding: isCompact ? 12 : null,
              compactIconSize: isCompact ? 16 : null,
              compactValueSize: isCompact ? 18 : null,
            ),
            StatCard(
              title: widget.user.isAdmin ? 'Unassigned' : 'New Leads',
              value: widget.user.isAdmin
                  ? '$unassignedCount'
                  : '${visibleLeads.where((l) => l.status == LeadStatus.newLead).length}',
              change: widget.user.isAdmin ? 'Require Allotment' : '+8.4%',
              icon: widget.user.isAdmin
                  ? Icons.warning_amber_rounded
                  : Icons.person_add_alt_outlined,
              compactPadding: isCompact ? 12 : null,
              compactIconSize: isCompact ? 16 : null,
              compactValueSize: isCompact ? 18 : null,
            ),
            StatCard(
              title: 'Qualified',
              value:
                  '${visibleLeads.where((l) => l.status == LeadStatus.qualified).length}',
              change: '+6.2%',
              icon: Icons.verified_outlined,
              compactPadding: isCompact ? 12 : null,
              compactIconSize: isCompact ? 16 : null,
              compactValueSize: isCompact ? 18 : null,
            ),
            StatCard(
              title: 'Converted',
              value:
                  '${visibleLeads.where((l) => l.status == LeadStatus.converted).length}',
              change: '+14.1%',
              icon: Icons.check_circle_outline,
              compactPadding: isCompact ? 12 : null,
              compactIconSize: isCompact ? 16 : null,
              compactValueSize: isCompact ? 18 : null,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RECENT LEADS HEADER
  // ============================================================

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'Recent leads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      AppTheme.textPrimary,
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Latest leads from your campaigns',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        TextButton(
          onPressed: () {
            setState(() {
              currentIndex = 1;
            });
          },

          child: const Text(
            'View all',
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VIEW ALL
  // ============================================================

  Widget _buildViewAllButton() {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          currentIndex = 1;
        });
      },

      style:
          OutlinedButton.styleFrom(
        minimumSize:
            const Size(
          double.infinity,
          46,
        ),

        side:
            const BorderSide(
          color:
              AppTheme.border,
        ),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        backgroundColor:
            Colors.white,
      ),

      child: const Row(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Text(
            'View all leads',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppTheme.textPrimary,
            ),
          ),

          SizedBox(width: 6),

          Icon(
            Icons.arrow_forward_rounded,
            size: 17,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TODAY SUMMARY
  // ============================================================

  Widget _buildTodaySummary() {
    return Container(
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppTheme.border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            "Today's activity",
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 15),

          _activityRow(
            icon:
                Icons.person_add_outlined,
            title:
                'New leads',
            value:
                '18',
            color:
                AppTheme.primary,
          ),

          _activityRow(
            icon:
                Icons.phone_outlined,
            title:
                'Follow-ups',
            value:
                '12',
            color:
                const Color(
              0xFFEA580C,
            ),
          ),

          _activityRow(
            icon:
                Icons.verified_outlined,
            title:
                'Qualified',
            value:
                '7',
            color:
                const Color(
              0xFF16A34A,
            ),
          ),

          _activityRow(
            icon:
                Icons.check_circle_outline,
            title:
                'Converted',
            value:
                '4',
            color:
                const Color(
              0xFF0F766E,
            ),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 11,
      ),

      decoration:
          isLast
              ? null
              : const BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(
                      color:
                          AppTheme.border,
                    ),
                  ),
                ),

      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,

            decoration:
                BoxDecoration(
              color:
                  color.withValues(
                alpha: 0.1,
              ),

              borderRadius:
                  BorderRadius.circular(
                9,
              ),
            ),

            child: Icon(
              icon,
              size: 17,
              color: color,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 12,
                color:
                    AppTheme.textSecondary,
              ),
            ),
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DEMO LEADS
// ============================================================

final List<Lead> _demoLeads = [
  Lead(
    id: 'L001',
    name: 'Rahul Sharma',
    phone: '+91 98765 43210',
    email: 'rahul@example.com',
    source: 'Facebook',
    campaign: 'Summer Campaign',
    status: LeadStatus.newLead,
    assignedTo: '', // UNASSIGNED -> For Administrator to allot
    createdAt: DateTime.now(),
    note: 'Interested in 3BHK premium apartment.',
  ),
  Lead(
    id: 'L002',
    name: 'Priya Patil',
    phone: '+91 98234 11223',
    email: 'priya@example.com',
    source: 'Instagram',
    campaign: 'Product Launch',
    status: LeadStatus.contacted,
    assignedTo: 'Amit Patil', // Allotted to Amit Patil
    createdAt: DateTime.now().subtract(
      const Duration(hours: 3),
    ),
    note: 'Requested brochure and pricing sheet.',
  ),
  Lead(
    id: 'L003',
    name: 'Aditya Kulkarni',
    phone: '+91 97654 88991',
    email: 'aditya@example.com',
    source: 'Facebook',
    campaign: 'Lead Generation',
    status: LeadStatus.qualified,
    assignedTo: 'Priya Shah', // Allotted to Priya Shah
    createdAt: DateTime.now().subtract(
      const Duration(days: 1),
    ),
    note: 'Demo and site visit scheduled.',
  ),
  Lead(
    id: 'L004',
    name: 'Sneha Joshi',
    phone: '+91 99887 77665',
    email: 'sneha@example.com',
    source: 'Instagram',
    campaign: 'Brand Awareness',
    status: LeadStatus.converted,
    assignedTo: 'Amit Patil', // Allotted to Amit Patil
    createdAt: DateTime.now().subtract(
      const Duration(days: 2),
    ),
    note: 'Booking deposit confirmed.',
  ),
  Lead(
    id: 'L005',
    name: 'Akash More',
    phone: '+91 90909 12345',
    email: 'akash@example.com',
    source: 'Facebook',
    campaign: 'Summer Campaign',
    status: LeadStatus.newLead,
    assignedTo: '', // UNASSIGNED -> For Administrator to allot
    createdAt: DateTime.now().subtract(
      const Duration(days: 2),
    ),
    note: 'Enquired through Facebook form.',
  ),
  Lead(
    id: 'L006',
    name: 'Vikram Deshmukh',
    phone: '+91 98450 11990',
    email: 'vikram@example.com',
    source: 'Google Ads',
    campaign: 'Search Campaign',
    status: LeadStatus.qualified,
    assignedTo: 'Priya Shah', // Allotted to Priya Shah
    createdAt: DateTime.now().subtract(
      const Duration(days: 3),
    ),
    note: 'Commercial space enquiry.',
  ),
  Lead(
    id: 'L007',
    name: 'Ananya Verma',
    phone: '+91 97123 44556',
    email: 'ananya@example.com',
    source: 'Website',
    campaign: 'Direct Organic',
    status: LeadStatus.newLead,
    assignedTo: '', // UNASSIGNED -> For Administrator to allot
    createdAt: DateTime.now().subtract(
      const Duration(days: 4),
    ),
    note: 'Filled website contact us form.',
  ),
];
