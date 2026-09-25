import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/lead_card.dart';
import '../widgets/stat_card.dart';
import 'analytics_screen.dart';
import 'followups_screen.dart';
import 'lead_screen.dart';
import 'more_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  int currentIndex = 0;

  final List<Lead> leads = _demoLeads;

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------
    // 1. LEADS
    // ------------------------------------------
    if (currentIndex == 1) {
      return LeadsScreen(
        leads: leads,
        onNavigationChanged: _handleNavigation,
      );
    }

    // ------------------------------------------
    // 2. FOLLOW-UPS
    // ------------------------------------------
    if (currentIndex == 2) {
      return Scaffold(
        body: const FollowupsScreen(),

        bottomNavigationBar:
            AppBottomNavigation(
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
        body: const AnalyticsScreen(),

        bottomNavigationBar:
            AppBottomNavigation(
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
        body: const MoreScreen(),

        bottomNavigationBar:
            AppBottomNavigation(
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

      appBar: AppBar(
        backgroundColor: Colors.white,

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),

            SizedBox(height: 2),

            Text(
              'Your CRM overview',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),

        actions: [
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
            padding:
                const EdgeInsets.only(
              right: 16,
            ),

            child: GestureDetector(
              onTap: () {
                setState(() {
                  currentIndex = 4;
                });
              },

              child: const CircleAvatar(
                radius: 18,

                backgroundColor:
                    Color(0xFFDBEAFE),

                child: Text(
                  'S',
                  style: TextStyle(
                    color: AppTheme.primary,
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
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),

          children: [
            // Welcome banner
            _buildWelcome(),

            const SizedBox(height: 22),

            // Statistics
            _buildStats(),

            const SizedBox(height: 26),

            // Recent leads header
            _buildSectionHeader(),

            const SizedBox(height: 12),

            // Recent leads
            ...leads.take(4).map(
              (lead) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),

                  child: LeadCard(
                    lead: lead,
                    compact: true,
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

      bottomNavigationBar:
          AppBottomNavigation(
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
                const Text(
                  'Good evening, Shantanu 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Here is what is happening with your leads today.',
                  style: TextStyle(
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
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.15,
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),

                    child: const Row(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        Icon(
                          Icons.people_outline,
                          color:
                              Colors.white,
                          size: 16,
                        ),

                        SizedBox(width: 6),

                        Text(
                          'View leads',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 12,
                            fontWeight:
                                FontWeight
                                    .w600,
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

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha: 0.12,
              ),

              borderRadius:
                  BorderRadius.circular(
                17,
              ),
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
              title: 'Total Leads',
              value: '1,248',
              change: '+12.5%',
              icon:
                  Icons.people_alt_outlined,

              compactPadding:
                  isCompact
                      ? 12
                      : null,

              compactIconSize:
                  isCompact
                      ? 16
                      : null,

              compactValueSize:
                  isCompact
                      ? 18
                      : null,
            ),

            StatCard(
              title: 'New Leads',
              value: '86',
              change: '+8.4%',
              icon:
                  Icons.person_add_alt_outlined,

              compactPadding:
                  isCompact
                      ? 12
                      : null,

              compactIconSize:
                  isCompact
                      ? 16
                      : null,

              compactValueSize:
                  isCompact
                      ? 18
                      : null,
            ),

            StatCard(
              title: 'Qualified',
              value: '324',
              change: '+6.2%',
              icon:
                  Icons.verified_outlined,

              compactPadding:
                  isCompact
                      ? 12
                      : null,

              compactIconSize:
                  isCompact
                      ? 16
                      : null,

              compactValueSize:
                  isCompact
                      ? 18
                      : null,
            ),

            StatCard(
              title: 'Converted',
              value: '96',
              change: '+14.1%',
              icon:
                  Icons.check_circle_outline,

              compactPadding:
                  isCompact
                      ? 12
                      : null,

              compactIconSize:
                  isCompact
                      ? 16
                      : null,

              compactValueSize:
                  isCompact
                      ? 18
                      : null,
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
    assignedTo: 'Shantanu',
    createdAt: DateTime.now(),
    note: '',
  ),

  Lead(
    id: 'L002',
    name: 'Priya Patil',
    phone: '+91 98234 11223',
    email: 'priya@example.com',
    source: 'Instagram',
    campaign: 'Product Launch',
    status: LeadStatus.contacted,
    assignedTo: 'Amit',
    createdAt:
        DateTime.now().subtract(
      const Duration(
        hours: 3,
      ),
    ),
    note: '',
  ),

  Lead(
    id: 'L003',
    name: 'Aditya Kulkarni',
    phone: '+91 97654 88991',
    email: 'aditya@example.com',
    source: 'Facebook',
    campaign: 'Lead Generation',
    status: LeadStatus.qualified,
    assignedTo: 'Shantanu',
    createdAt:
        DateTime.now().subtract(
      const Duration(
        days: 1,
      ),
    ),
    note: '',
  ),

  Lead(
    id: 'L004',
    name: 'Sneha Joshi',
    phone: '+91 99887 77665',
    email: 'sneha@example.com',
    source: 'Instagram',
    campaign: 'Brand Awareness',
    status: LeadStatus.converted,
    assignedTo: 'Amit',
    createdAt:
        DateTime.now().subtract(
      const Duration(
        days: 2,
      ),
    ),
    note: '',
  ),

  Lead(
    id: 'L005',
    name: 'Akash More',
    phone: '+91 90909 12345',
    email: 'akash@example.com',
    source: 'Facebook',
    campaign: 'Summer Campaign',
    status: LeadStatus.newLead,
    assignedTo: 'Shantanu',
    createdAt:
        DateTime.now().subtract(
      const Duration(
        days: 2,
      ),
    ),
    note: '',
  ),
];
