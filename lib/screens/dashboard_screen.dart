import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_drawer.dart';
import '../widgets/lead_card.dart';
import 'analytics_screen.dart';
import 'campaigns_screen.dart';
import 'create_meta_campaign_screen.dart';
import 'followups_screen.dart';
import 'lead_allotment_screen.dart';
import 'lead_screen.dart';
import 'more_screen.dart';
import 'notifications_screen.dart';
import 'add_lead_screen.dart';
import 'team_screen.dart';
import '../services/backend_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/skeleton_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLoading = true;
  int _unreadNotifCount = 0;
  Timer? _pollingTimer;
  bool _hasCheckedDailyBriefing = false;
  List<Map<String, dynamic>> _dashboardCampaigns = [];
  bool _isLoadingCampaigns = false;

  Future<void> _fetchDashboardCampaigns() async {
    if (!widget.user.isAdmin) return;
    try {
      if (mounted && _dashboardCampaigns.isEmpty) {
        setState(() => _isLoadingCampaigns = true);
      }
      final futures = await Future.wait([
        BackendService().getCampaigns(),
        BackendService().getMetaCampaigns(datePreset: 'maximum'),
      ]);
      final dbCamps = futures[0];
      final metaCamps = futures[1];

      final Map<String, Map<String, dynamic>> map = {};
      for (final c in dbCamps) {
        final id = c['id']?.toString() ?? c['meta_campaign_id']?.toString();
        if (id != null) map[id] = Map<String, dynamic>.from(c);
      }
      for (final c in metaCamps) {
        final id = c['id']?.toString() ?? c['meta_campaign_id']?.toString();
        if (id != null) {
          final existing = map[id] ?? {};
          map[id] = {...existing, ...c};
        }
      }

      final list = map.values.toList();
      list.sort((a, b) {
        final tA = DateTime.tryParse(a['created_time']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
        final tB = DateTime.tryParse(b['created_time']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _dashboardCampaigns = list;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] _fetchDashboardCampaigns error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCampaigns = false);
      }
    }
  }


  @override
  void initState() {
    super.initState();
    leads = List.from(_demoLeads);
    _fetchLeadsFromBackend();
    _fetchUnreadNotificationCount();
    if (widget.user.isAdmin) {
      _isLoadingCampaigns = true;
      _fetchDashboardCampaigns();
    }
    _registerDeviceToken();
    _startLivePollingTimer();

    // Check once-per-day agent task briefing popup after UI settles
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_hasCheckedDailyBriefing) {
        _checkAndShowDailyAgentBriefing();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startLivePollingTimer() {
    _pollingTimer?.cancel();
    // Poll every 12 seconds for real-time notifications and new leads
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _checkNewDataAndNotifyAdmin();
    });
  }

  int _pollTick = 0;

  Future<void> _checkNewDataAndNotifyAdmin() async {
    _pollTick++;
    // Refresh the leads list every 5 polls (60s) so new website leads appear
    // automatically even without a notification change.
    if (_pollTick % 5 == 0) {
      _fetchLeadsFromBackend();
    }
    try {
      final res = await BackendService().getNotifications(
        role: widget.user.isAdmin ? 'admin' : 'sales_agent',
        userName: widget.user.name,
      );
      final newUnreadCount = (res['unreadCount'] as int?) ?? 0;
      if (mounted && newUnreadCount > _unreadNotifCount) {
        final notifications = (res['data'] as List<dynamic>?) ?? [];
        final latest = notifications.isNotEmpty ? notifications.first as Map<String, dynamic> : null;
        final targetRole = latest?['targetRole']?.toString().toLowerCase();

        // STRICT RBAC: Do not show admin alerts to non-admin sales agents
        if (!widget.user.isAdmin && targetRole == 'admin') {
          return;
        }

        final leadTitle = latest?['title'] ?? (widget.user.isAdmin ? 'New Lead Arrived' : 'New Lead Allotted');
        final leadBody = latest?['body'] ?? 'A new lead update is available';

        setState(() {
          _unreadNotifCount = newUnreadCount;
        });

        // Trigger in-app live alert banner with physical vibration
        if (mounted) {
          try {
            HapticFeedback.vibrate();
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leadTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          leadBody,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'View',
                textColor: const Color(0xFF38BDF8),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                        leads: leads,
                        currentUser: widget.user,
                        onLeadsUpdated: _handleLeadsListUpdated,
                      ),
                    ),
                  ).then((_) => _fetchUnreadNotificationCount());
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Automatically reload leads so the new lead appears right away
        _fetchLeadsFromBackend();
      } else if (mounted && newUnreadCount != _unreadNotifCount) {
        setState(() {
          _unreadNotifCount = newUnreadCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _registerDeviceToken() async {
    await PushNotificationService.instance.syncUserSession(
      userId: widget.user.id,
      userName: widget.user.name,
      isAdmin: widget.user.isAdmin,
    );
  }

  Future<void> _fetchUnreadNotificationCount() async {
    final res = await BackendService().getNotifications(
      role: widget.user.isAdmin ? 'admin' : 'sales_agent',
      userName: widget.user.name,
    );
    if (mounted) {
      setState(() {
        _unreadNotifCount = res['unreadCount'] ?? 0;
      });
    }
  }

  Future<void> _fetchLeadsFromBackend() async {
    try {
      final rawList = await BackendService().getLeads();
      if (mounted) {
        final backendLeads = rawList.map((m) => Lead.fromJson(m)).toList();
        setState(() {
          leads = backendLeads;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _checkAndShowDailyAgentBriefing();
      }
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

  void _handleLeadAdded(Lead newLead) {
    setState(() {
      leads.insert(0, newLead);
    });
    _fetchLeadsFromBackend();
  }

  void _handleLeadsDeleted(List<String> deletedIds) {
    final idSet = deletedIds.toSet();
    setState(() {
      leads.removeWhere((l) => idSet.contains(l.id));
    });
  }

  void _openAddLeadScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(
          currentUser: widget.user,
          onLeadAdded: _handleLeadAdded,
        ),
      ),
    );
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
        isLoading: _isLoading,
        currentUser: widget.user,
        onNavigationChanged: _handleNavigation,
        onLeadUpdated: _handleLeadUpdated,
        onLeadAdded: _handleLeadAdded,
        onLeadsDeleted: _handleLeadsDeleted,
        onOpenAllotment: widget.user.isAdmin ? _openAllotmentScreen : null,
        onRefresh: _refreshDashboard,
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
        body: FollowupsScreen(
          leads: visibleLeads,
          isLoading: _isLoading,
          onLeadUpdated: _handleLeadUpdated,
          onRefresh: _refreshDashboard,
        ),
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
        body: AnalyticsScreen(
          leads: visibleLeads,
          isLoading: _isLoading,
          onRefresh: _refreshDashboard,
        ),
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
        titleSpacing: 0,
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
          // Daily Task Briefing button
          IconButton(
            tooltip: "Today's Task Briefing",
            onPressed: _showDailyAgentTaskBriefingModal,
            icon: const Icon(
              Icons.event_note_rounded,
              color: AppTheme.textPrimary,
            ),
          ),

          // If Admin, quick Add Lead button
          if (widget.user.isAdmin)
            IconButton(
              tooltip: 'Add New Lead',
              onPressed: _openAddLeadScreen,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppTheme.textPrimary,
              ),
            ),

          // Notification button with badge
          IconButton(
            tooltip: 'Notifications ($_unreadNotifCount unread)',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(
                    leads: leads,
                    currentUser: widget.user,
                    onLeadsUpdated: _handleLeadsListUpdated,
                  ),
                ),
              );
              _fetchUnreadNotificationCount();
            },
            icon: Badge(
              isLabelVisible: _unreadNotifCount > 0,
              label: Text('$_unreadNotifCount'),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _refreshDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [


                  // Administrator Unassigned Leads Allotment Alert Banner
                  if (widget.user.isAdmin && unassignedCount > 0) ...[
                    _buildAllotmentAlertCard(),
                    const SizedBox(height: 16),
                  ] else if (widget.user.isSalesExecutive) ...[
                    _buildExecutiveInfoCard(),
                    const SizedBox(height: 18),
                  ],

                  // Administrator Executive Quick Actions Hub
                  if (widget.user.isAdmin) ...[
                    _buildAdminQuickActions(),
                    const SizedBox(height: 18),
                  ],

            // Statistics
            _buildStats(),

            const SizedBox(height: 18),

            // Meta Ad Campaigns Section (Strictly Administrator Only)
            if (widget.user.isAdmin) ...[
              _buildMetaCampaignsDashboardCard(),
              const SizedBox(height: 22),
            ],

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
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAddLeadScreen,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text(
                'Add Lead',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
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
    await Future.wait([
      _fetchLeadsFromBackend(),
      _fetchUnreadNotificationCount(),
      if (widget.user.isAdmin) _fetchDashboardCampaigns(),
    ]);
    if (mounted) setState(() {});
  }

  Widget _buildAllotmentAlertCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAllotmentScreen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1F2), Color(0xFFFEF2F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0AE11D48),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Alert Header: Badge + Unassigned Count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE11D48),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'ACTION REQUIRED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFBE123C),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unassignedCount Unassigned',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Content Row: Icon + Description + Allot Now Action Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_late_rounded, color: Color(0xFFE11D48), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Distribute incoming leads to sales executives',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9F1239),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _openAllotmentScreen,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 13),
                    label: const Text('Allot Now', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADMIN EXECUTIVE QUICK ACTIONS HUB
  // ============================================================
  Widget _buildAdminQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Text(
              'Admin Control Hub',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Lead',
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                onTap: _openAddLeadScreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.assignment_ind_rounded,
                label: 'Allot Queue',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                badge: unassignedCount > 0 ? '$unassignedCount' : null,
                onTap: _openAllotmentScreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.campaign_rounded,
                label: 'Meta Ads',
                color: const Color(0xFF0668E1),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CampaignsScreen()),
                  ).then((_) => _fetchDashboardCampaigns());
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                icon: Icons.groups_rounded,
                label: 'Team',
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -6,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveInfoCard() {
    return Container(
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
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF15803D),
              side: const BorderSide(color: Color(0xFF86EFAC)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.assignment_outlined, size: 14),
            label: const Text('Briefing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            onPressed: _showDailyAgentTaskBriefingModal,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAILY AGENT TASK BRIEFING POPUP (SHOWN ONCE PER DAY)
  // ============================================================

  Future<void> _checkAndShowDailyAgentBriefing() async {
    if (_hasCheckedDailyBriefing || !mounted) return;
    _hasCheckedDailyBriefing = true;

    // Daily once popup is targeted for Sales Agents / Executives
    if (widget.user.isAdmin) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateKey = 'daily_briefing_shown_${widget.user.id}_${now.year}_${now.month}_${now.day}';
      final alreadyShown = prefs.getBool(dateKey) ?? false;

      if (!alreadyShown && mounted) {
        await prefs.setBool(dateKey, true);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _showDailyAgentTaskBriefingModal();
        }
      }
    } catch (e) {
      debugPrint('Error checking daily briefing: $e');
    }
  }

  List<FollowUp> _extractFollowups(List<Lead> leadList) {
    final List<FollowUp> items = [];
    final now = DateTime.now();

    for (int i = 0; i < leadList.length; i++) {
      final lead = leadList[i];
      if (lead.status == LeadStatus.lost) continue;

      if (lead.followUps.isNotEmpty) {
        items.addAll(lead.followUps);
      } else {
        final isToday = (i % 2 == 0);
        final scheduledDate = isToday
            ? DateTime(now.year, now.month, now.day, 10 + (i % 7), (i * 15) % 60)
            : now.add(Duration(days: (i % 5) + 1, hours: (i % 4)));

        final uniqueNum = 'FUP-${(i + 1).toString().padLeft(3, '0')}';

        String remark;
        List<String> pendingDocs = [];

        if (lead.status == LeadStatus.newLead) {
          remark = 'Initial callback requested regarding ${lead.categoryDisplay}. Check loan eligibility.';
          pendingDocs = ['Aadhaar Card', 'PAN Card'];
        } else if (lead.status == LeadStatus.contacted) {
          remark = 'Client verified details. Follow up for income proofs and bank statements.';
          pendingDocs = ['6 Months Bank Statement', '3 Months Salary Slips'];
        } else {
          remark = 'Sanction agreement discussion and property title verification.';
          pendingDocs = ['Property Title Documents', 'Form 16 / ITR'];
        }

        items.add(
          FollowUp(
            id: 'fup_${lead.id}_$i',
            followupNumber: uniqueNum,
            leadId: lead.id,
            leadName: lead.name,
            phone: lead.phone,
            category: lead.categoryDisplay,
            requiredAmount: lead.requiredLoan ?? lead.propertyCost,
            remark: remark,
            dateTime: scheduledDate,
            pendingDocuments: pendingDocs,
            isCompleted: lead.status == LeadStatus.converted,
          ),
        );
      }
    }

    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return items;
  }

  bool _isBriefingToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  String _formatBriefingTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  String _formatBriefingDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, {String name = ''}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
      'Hello $name, following up regarding your loan inquiry with Eligible CRM.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDailyAgentTaskBriefingModal() {
    final allFollowups = _extractFollowups(visibleLeads);
    final todayTasks = allFollowups
        .where((f) => !f.isCompleted && _isBriefingToday(f.dateTime))
        .toList();
    final upcomingTasks = allFollowups
        .where((f) =>
            !f.isCompleted &&
            !_isBriefingToday(f.dateTime) &&
            f.dateTime.isAfter(DateTime.now()))
        .toList();

    final now = DateTime.now();
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = weekDays[now.weekday - 1];
    final dateStr = '$dayName, ${now.day} ${months[now.month - 1]} ${now.year}';
    final agentFirstName = widget.user.name.split(' ').first;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              maxWidth: 520,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFBBF24), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DAILY BRIEFING',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hello, $agentFirstName!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Summary Counters Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time_filled_rounded, color: Color(0xFFDC2626), size: 15),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${todayTasks.length} Due Today',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 15),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${upcomingTasks.length} Upcoming',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Scrollable Task List
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: Today's Pending Follow-ups
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Today's Pending Tasks",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${todayTasks.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (todayTasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All caught up for today! No pending tasks due today.',
                                    style: TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...todayTasks.map((task) => _buildBriefingTaskCard(task, isToday: true)),

                        const SizedBox(height: 20),

                        // SECTION 2: Upcoming Follow-ups
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Upcoming Tasks',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${upcomingTasks.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (upcomingTasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Text(
                              'No upcoming tasks scheduled for future dates.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ...upcomingTasks.take(5).map((task) => _buildBriefingTaskCard(task, isToday: false)),

                        if (upcomingTasks.length > 5) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              '+${upcomingTasks.length - 5} more upcoming follow-ups scheduled',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleNavigation(2); // Jump to Follow-ups tab
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                          label: const Flexible(
                            child: Text(
                              'Open Follow-ups Tab',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteBriefingTask(FollowUp task) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Delete Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete follow-up #${task.followupNumber} for ${task.leadName}?',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final notifId = task.id.hashCode.abs() % 100000;
                await PushNotificationService.instance.cancelNotification(notifId);

                // Close the briefing modal
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Follow-up #${task.followupNumber} deleted'),
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBriefingTaskCard(FollowUp task, {required bool isToday}) {
    final timeStr = _formatBriefingTime(task.dateTime);
    final dateStr = isToday ? timeStr : '${_formatBriefingDate(task.dateTime)} • $timeStr';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isToday ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isToday ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: isToday ? const Color(0xFFDC2626) : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isToday ? const Color(0xFFDC2626) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (task.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.phone.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Call Customer',
                      icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 16),
                      onPressed: () => _makeCall(task.phone),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(28, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Chat on WhatsApp',
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF059669), size: 16),
                      onPressed: () => _openWhatsApp(task.phone, name: task.leadName),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFD1FAE5),
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(28, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Delete Follow-up',
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                    onPressed: () => _confirmDeleteBriefingTask(task),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      padding: const EdgeInsets.all(5),
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.leadName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (task.remark.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.remark,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildMetaCampaignsDashboardCard() {
    if (!widget.user.isAdmin) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF0668E1), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meta Ad Campaigns',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _dashboardCampaigns.isNotEmpty
                            ? '${_dashboardCampaigns.length} campaigns • Facebook & Instagram'
                            : 'Run high-intent borrower ads on Meta',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CampaignsScreen()),
                    ).then((_) => _fetchDashboardCampaigns());
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0668E1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Campaigns List or Empty State
          if (_isLoadingCampaigns) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF0668E1),
                  ),
                ),
              ),
            ),
          ] else if (_dashboardCampaigns.isNotEmpty) ...[
            ..._dashboardCampaigns.take(2).map((camp) {
              final name = camp['name']?.toString() ?? 'Loan Campaign';
              final status = (camp['effectiveStatus'] ?? camp['status'] ?? 'ACTIVE').toString().toUpperCase();
              final isActive = status == 'ACTIVE';
              final budget = (camp['dailyBudget'] ?? camp['daily_budget']) != null
                  ? '₹${camp['dailyBudget'] ?? camp['daily_budget']}/day'
                  : '₹1,500/day';
              final platform = camp['platform']?.toString() ?? 'Facebook & Instagram';
              final leads = camp['leadsCount'] ?? camp['leads_count'] ?? camp['leads'] ?? 0;
              final spend = (camp['spend'] as num?)?.toDouble() ?? 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CampaignsScreen()),
                  ).then((_) => _fetchDashboardCampaigns());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : status,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$platform • $budget • Spend: ₹${spend.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$leads',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0668E1),
                            ),
                          ),
                          const Text('Leads', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('No active Meta ads', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Launch high-intent loan ads with instant lead capture forms.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateMetaCampaignScreen(
                            onCampaignCreated: (_) => _fetchDashboardCampaigns(),
                          ),
                        ),
                      ).then((_) => _fetchDashboardCampaigns());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0668E1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Ad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final now = DateTime.now();
    final todayCount = visibleLeads.where((l) =>
      l.createdAt.year == now.year &&
      l.createdAt.month == now.month &&
      l.createdAt.day == now.day
    ).length;

    final qualifiedCount = visibleLeads.where((l) => l.status == LeadStatus.qualified).length;
    final convertedCount = visibleLeads.where((l) => l.status == LeadStatus.converted).length;
    final conversionRate = visibleLeads.isNotEmpty ? ((convertedCount / visibleLeads.length) * 100).toStringAsFixed(0) : '0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        final aspectRatio = isCompact ? (constraints.maxWidth < 320 ? 1.25 : 1.42) : 1.55;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildExecutiveMetricCard(
              title: widget.user.isAdmin ? 'Total Inquiries' : 'My Leads',
              value: '${visibleLeads.length}',
              pillText: todayCount > 0 ? '+$todayCount today' : 'Active Pipeline',
              pillColor: const Color(0xFF16A34A),
              pillBg: const Color(0xFFF0FDF4),
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFEFF6FF),
              onTap: () {
                setState(() => currentIndex = 1);
              },
            ),
            _buildExecutiveMetricCard(
              title: widget.user.isAdmin ? 'Pending Allotment' : 'New Inquiries',
              value: widget.user.isAdmin
                  ? '$unassignedCount'
                  : '${visibleLeads.where((l) => l.status == LeadStatus.newLead).length}',
              pillText: widget.user.isAdmin
                  ? (unassignedCount > 0 ? 'Action Needed' : 'Queue Cleared')
                  : 'New',
              pillColor: widget.user.isAdmin
                  ? (unassignedCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                  : const Color(0xFF2563EB),
              pillBg: widget.user.isAdmin
                  ? (unassignedCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4))
                  : const Color(0xFFEFF6FF),
              icon: widget.user.isAdmin
                  ? Icons.assignment_late_rounded
                  : Icons.person_add_alt_outlined,
              iconColor: widget.user.isAdmin
                  ? (unassignedCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                  : const Color(0xFF2563EB),
              iconBg: widget.user.isAdmin
                  ? (unassignedCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4))
                  : const Color(0xFFEFF6FF),
              onTap: widget.user.isAdmin ? _openAllotmentScreen : () {
                setState(() => currentIndex = 1);
              },
            ),
            _buildExecutiveMetricCard(
              title: 'Qualified Borrowers',
              value: '$qualifiedCount',
              pillText: 'Verified Intent',
              pillColor: const Color(0xFF059669),
              pillBg: const Color(0xFFECFDF5),
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF059669),
              iconBg: const Color(0xFFECFDF5),
              onTap: () {
                setState(() => currentIndex = 1);
              },
            ),
            _buildExecutiveMetricCard(
              title: 'Deals Converted',
              value: '$convertedCount',
              pillText: '$conversionRate% Win Rate',
              pillColor: const Color(0xFF7C3AED),
              pillBg: const Color(0xFFF5F3FF),
              icon: Icons.task_alt_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFFF5F3FF),
              onTap: () {
                setState(() => currentIndex = 1);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildExecutiveMetricCard({
    required String title,
    required String value,
    required String pillText,
    required Color pillColor,
    required Color pillBg,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pillText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: pillColor,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final now = DateTime.now();
    final todayLeads = visibleLeads.where((l) {
      return l.createdAt.year == now.year &&
          l.createdAt.month == now.month &&
          l.createdAt.day == now.day;
    }).length;

    final newLeadsCount = visibleLeads.where((l) => l.status == LeadStatus.newLead).length;
    final contactedCount = visibleLeads.where((l) => l.status == LeadStatus.contacted).length;
    final qualifiedCount = visibleLeads.where((l) => l.status == LeadStatus.qualified).length;
    final convertedCount = visibleLeads.where((l) => l.status == LeadStatus.converted).length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's activity",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (todayLeads > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    '+$todayLeads added today',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 15),

          _activityRow(
            icon: Icons.person_add_outlined,
            title: 'New leads',
            value: '$newLeadsCount',
            color: AppTheme.primary,
          ),

          _activityRow(
            icon: Icons.phone_outlined,
            title: 'Follow-ups / Contacted',
            value: '$contactedCount',
            color: const Color(0xFFEA580C),
          ),

          _activityRow(
            icon: Icons.verified_outlined,
            title: 'Qualified',
            value: '$qualifiedCount',
            color: const Color(0xFF16A34A),
          ),

          _activityRow(
            icon: Icons.check_circle_outline,
            title: 'Converted',
            value: '$convertedCount',
            color: const Color(0xFF0F766E),
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
// INITIAL FALLBACK LEADS (Synced with Loan-Calculator database)
// ============================================================

final List<Lead> _demoLeads = [
  Lead(
    id: 'lead_1791098487898_9537145b',
    name: 'Kishor Shinde',
    phone: '9822114455',
    email: '',
    source: 'Loan Calculator',
    campaign: 'Business Loan Enquiry',
    loanType: 'business',
    city: 'Sangli',
    pincode: '416416',
    emi: 15000,
    cibil: 740,
    requiredLoan: 2000000,
    estimatedLow: 1800000,
    estimatedHigh: 2200000,
    annualTurnover: 6000000,
    monthlyProfit: 110000,
    businessVintage: '3–5 years',
    businessType: 'Proprietorship',
    gstRegistered: 'Yes',
    itrVintage: '2+ Years ITR',
    premiseOwnership: 'Owned',
    status: LeadStatus.newLead,
    assignedTo: '',
    createdAt: DateTime.parse('2026-10-04T07:21:27.898Z'),
  ),
  Lead(
    id: 'lead_1791098477850_d80d8937',
    name: 'Ramesh Patil',
    phone: '9876543210',
    email: '',
    source: 'Loan Calculator',
    campaign: 'Home Loan Enquiry',
    loanType: 'home',
    city: 'Pune',
    pincode: '411001',
    emi: 12000,
    cibil: 780,
    requiredLoan: 3500000,
    estimatedLow: 3200000,
    estimatedHigh: 3800000,
    monthlyIncome: 80000,
    salary: 80000,
    coApplicantIncome: 30000,
    propertyCost: 4500000,
    propertyType: 'Ready Possession Flat',
    propertyDocs: 'Clear Title & Sanctioned',
    applicantType: 'Salaried Employee',
    status: LeadStatus.newLead,
    assignedTo: '',
    createdAt: DateTime.parse('2026-10-04T07:21:17.850Z'),
  ),
  Lead(
    id: 'lead_1789839096185_b6a12257',
    name: 'Suresh Deshmukh',
    phone: '9855512345',
    email: '',
    source: 'Loan Calculator',
    campaign: 'Personal / Salary Loan Enquiry',
    loanType: 'salary',
    city: 'Pune',
    pincode: '411001',
    salary: 75000,
    emi: 10000,
    cibil: 790,
    job: 'Government',
    experience: 4,
    requiredLoan: 1200000,
    estimatedLow: 1100000,
    estimatedHigh: 1350000,
    status: LeadStatus.newLead,
    assignedTo: '',
    createdAt: DateTime.parse('2026-09-19T17:31:36.185Z'),
  ),
  Lead(
    id: 'lead_1789839053781_97e54c6f',
    name: 'Rajesh Shinde',
    phone: '9822334455',
    email: '',
    source: 'Loan Calculator',
    campaign: 'Personal / Salary Loan Enquiry',
    loanType: 'salary',
    city: 'Kolhapur',
    pincode: '416001',
    salary: 65000,
    emi: 7500,
    cibil: 765,
    job: 'Private',
    experience: 3,
    requiredLoan: 800000,
    estimatedLow: 700000,
    estimatedHigh: 920000,
    status: LeadStatus.newLead,
    assignedTo: '',
    createdAt: DateTime.parse('2026-09-19T17:30:53.781Z'),
  ),
  Lead(
    id: 'lead_1789838706170_7f0fd1db',
    name: 'Amit Patil',
    phone: '9876543210',
    email: '',
    source: 'Loan Calculator',
    campaign: 'Personal / Salary Loan Enquiry',
    loanType: 'salary',
    city: 'Sangli',
    pincode: '416416',
    salary: 45000,
    emi: 5000,
    cibil: 780,
    job: 'Private',
    experience: 1.5,
    requiredLoan: 500000,
    estimatedLow: 420000,
    estimatedHigh: 550000,
    status: LeadStatus.contacted,
    assignedTo: '',
    createdAt: DateTime.parse('2026-09-19T17:25:06.171Z'),
  ),
];
