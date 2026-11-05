import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'lead_detail.dart';

class NotificationsScreen extends StatefulWidget {
  final List<Lead> leads;
  final UserModel? currentUser;
  final Function(List<Lead>)? onLeadsUpdated;

  const NotificationsScreen({
    super.key,
    this.leads = const [],
    this.currentUser,
    this.onLeadsUpdated,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final BackendService _backend = BackendService();

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allNotifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isAdminUser ? 3 : 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final res = await _backend.getNotifications(
      role: _isAdminUser ? 'admin' : 'sales_agent',
      userName: widget.currentUser?.name,
    );
    if (mounted) {
      final rawList = (res['data'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Strict client-side filter
      final list = _isAdminUser
          ? rawList
          : rawList.where((n) {
              final targetRole = n['targetRole']?.toString().toLowerCase();
              if (targetRole == 'admin') return false;
              if (targetRole == 'sales_agent' || targetRole == 'all' || targetRole == null) {
                final assignedTo = (n['assignedTo'] ?? n['targetUserName'] ?? n['targetUserId'])?.toString();
                if (assignedTo != null && 
                    assignedTo != 'Available for Claim' && 
                    assignedTo != 'Unassigned' && 
                    assignedTo.isNotEmpty) {
                  final currentName = widget.currentUser?.name.toLowerCase().trim() ?? '';
                  final assignedLower = assignedTo.toLowerCase().trim();
                  if (assignedLower != currentName && !assignedLower.contains(currentName) && !currentName.contains(assignedLower)) {
                    return false;
                  }
                }
                return true;
              }
              return false;
            }).toList();

      setState(() {
        _allNotifications = list;
        _unreadCount = list.where((n) => n['read'] != true).length;
        _isLoading = false;
      });
    }
  }

  bool get _isAdminUser => widget.currentUser?.isAdmin ?? true;

  Future<void> _markRead(String id) async {
    await _backend.markNotificationRead(id);
    if (mounted) {
      setState(() {
        final idx = _allNotifications.findIndex((n) => n['id'] == id);
        if (idx >= 0) {
          _allNotifications[idx]['read'] = true;
          _unreadCount = (_unreadCount - 1).clamp(0, 9999);
        }
      });
    }
  }

  Future<void> _markAllRead() async {
    await _backend.markAllNotificationsRead(role: _isAdminUser ? 'admin' : 'sales_agent', userName: widget.currentUser?.name);
    if (mounted) {
      setState(() {
        for (final n in _allNotifications) {
          n['read'] = true;
        }
        _unreadCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    // Only administrators are allowed to delete
    if (!_isAdminUser) return;
    setState(() {
      _allNotifications.removeWhere((n) => n['id'] == id);
      _unreadCount = _allNotifications.where((n) => n['read'] != true).length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearAllNotifications() {
    if (!_isAdminUser) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Clear Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all notifications? This action is available to administrators only.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _allNotifications.clear();
                _unreadCount = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications have been cleared by Admin'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }



  void _openLeadDetail(Map<String, dynamic> notif) {
    final leadId = notif['leadId'];
    Lead? matchedLead;

    try {
      matchedLead = widget.leads.firstWhere((l) => l.id == leadId);
    } catch (_) {
      final rawAssignedTo = (notif['assignedTo'] ?? '').toString().trim();
      final cleanAssignedTo = (rawAssignedTo.toLowerCase() == 'available for claim' ||
              rawAssignedTo.toLowerCase() == 'unassigned')
          ? ''
          : rawAssignedTo;

      matchedLead = Lead(
        id: leadId?.toString() ?? 'lead_notif_${DateTime.now().millisecondsSinceEpoch}',
        name: notif['leadName'] ?? 'Lead from Notification',
        phone: notif['leadPhone'] ?? '',
        email: '',
        source: notif['source'] ?? 'Meta Ads',
        campaign: notif['budget'] != null ? 'Budget: ${notif['budget']}' : 'Meta Ad Campaign',
        status: LeadStatus.newLead,
        assignedTo: cleanAssignedTo,
        createdAt: DateTime.now(),
        note: notif['body'] ?? 'Property Inquiry',
      );
    }

    _markRead(notif['id'] ?? '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(
          lead: matchedLead!,
          currentUser: widget.currentUser,
          onLeadUpdated: (updated) {
            final updatedList = widget.leads.map((l) => l.id == updated.id ? updated : l).toList();
            widget.onLeadsUpdated?.call(List<Lead>.from(updatedList));
          },
        ),
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'Recent';
    try {
      final date = DateTime.parse(isoString);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminNotifs = _allNotifications
        .where((n) => n['targetRole'] == 'admin')
        .toList();
    final salesNotifs = _allNotifications
        .where((n) => n['targetRole'] == 'sales_agent' || n['targetRole'] == 'all' || n['targetRole'] == null)
        .toList();
    final unreadNotifs = _allNotifications
        .where((n) => n['read'] != true)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isLoading ? null : _loadNotifications,
            tooltip: 'Refresh',
          ),
          if (_isAdminUser)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFDC2626), size: 22),
              onPressed: _allNotifications.isEmpty ? null : _confirmClearAllNotifications,
              tooltip: 'Clear All (Admin Only)',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (val) {
              if (val == 'mark_all_read') _markAllRead();
              if (val == 'clear_all') _confirmClearAllNotifications();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 18),
                    SizedBox(width: 10),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              if (_isAdminUser)
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Clear All Notifications', style: TextStyle(color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: _isAdminUser
              ? [
                  Tab(text: 'All (${_allNotifications.length})'),
                  Tab(text: 'Admin (${adminNotifs.length})'),
                  Tab(text: 'Sales (${salesNotifs.length})'),
                ]
              : [
                  Tab(text: 'All Alerts (${_allNotifications.length})'),
                  Tab(text: 'Unread (${unreadNotifs.length})'),
                ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _isAdminUser
                  ? [
                      _buildNotificationList(_allNotifications),
                      _buildNotificationList(adminNotifs, emptyLabel: 'No Admin alerts yet'),
                      _buildNotificationList(salesNotifs, emptyLabel: 'No Sales Agent alerts yet'),
                    ]
                  : [
                      _buildNotificationList(_allNotifications, emptyLabel: 'No notifications yet'),
                      _buildNotificationList(unreadNotifs, emptyLabel: 'No unread notifications'),
                    ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _unreadCount == 0 ? null : _markAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark All Read', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> list, {String emptyLabel = 'No notifications yet'}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 36,
                  color: Color(0xFF1877F2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'When a new lead arrives from Meta Ads, webhooks or direct database entry, instant alerts will display here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),

            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final notif = list[idx];
          return _buildNotificationCard(notif);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = notif['read'] == true;
    final role = notif['targetRole'] ?? 'all';
    final isAdmin = role == 'admin';
    final title = notif['title'] ?? 'New Lead Alert';
    final body = notif['body'] ?? '';
    final timeStr = _formatTime(notif['createdAt']);
    final leadName = notif['leadName'] ?? '';
    final budget = notif['budget'] ?? '';
    final source = notif['source'] ?? 'Meta Ads';

    final type = notif['type']?.toString().toUpperCase() ?? '';
    final isStatusChange = type == 'LEAD_STATUS_CHANGED';
    final isBulkAllot = type == 'LEADS_BULK_ALLOTTED';
    final isSingleAllot = type == 'LEAD_ALLOTTED_TO_YOU' || type == 'LEAD_ALLOTTED';

    final badgeLabel = isStatusChange
        ? 'STATUS UPDATE'
        : (isBulkAllot
            ? 'BULK ALLOTMENT'
            : (isSingleAllot
                ? 'ALLOTTED TO YOU'
                : (isAdmin ? 'ADMIN ALERT' : 'SALES TEAM')));

    final badgeBgColor = isStatusChange
        ? const Color(0xFFDCFCE7)
        : (isBulkAllot
            ? const Color(0xFFEDE9FE)
            : (isSingleAllot
                ? const Color(0xFFFEF3C7)
                : (isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7))));

    final badgeTextColor = isStatusChange
        ? const Color(0xFF15803D)
        : (isBulkAllot
            ? const Color(0xFF6D28D9)
            : (isSingleAllot
                ? const Color(0xFFB45309)
                : (isAdmin ? const Color(0xFF1E40AF) : const Color(0xFF92400E))));

    final iconData = isStatusChange
        ? Icons.published_with_changes_rounded
        : (isBulkAllot
            ? Icons.assignment_turned_in_rounded
            : (isSingleAllot
                ? Icons.assignment_ind_rounded
                : (isAdmin ? Icons.admin_panel_settings : Icons.trending_up)));

    final iconColor = isStatusChange
        ? const Color(0xFF16A34A)
        : (isBulkAllot
            ? const Color(0xFF7C3AED)
            : (isSingleAllot
                ? const Color(0xFFD97706)
                : (isAdmin ? const Color(0xFF1877F2) : const Color(0xFFD97706))));

    final iconBgColor = isStatusChange
        ? const Color(0xFFF0FDF4)
        : (isBulkAllot
            ? const Color(0xFFF5F3FF)
            : (isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)));

    return Container(
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppTheme.border : const Color(0xFFBFDBFE),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: isRead
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () => _openLeadDetail(notif),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1877F2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (leadName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            leadName,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    if (budget.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee, size: 13, color: Color(0xFF16A34A)),
                          Text(
                            budget,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        source,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Only Admin gets delete button; Sales executives do not
                  if (_isAdminUser)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                      onPressed: () => _deleteNotification(notif['id'] ?? ''),
                      tooltip: 'Delete Notification (Admin Only)',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  if (!isRead)
                    TextButton(
                      onPressed: () => _markRead(notif['id'] ?? ''),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Mark as read', style: TextStyle(fontSize: 11)),
                    ),
                  TextButton.icon(
                    onPressed: () => _openLeadDetail(notif),
                    icon: const Icon(Icons.arrow_forward, size: 12),
                    label: const Text('View Lead Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on List<Map<String, dynamic>> {
  int findIndex(bool Function(Map<String, dynamic>) predicate) {
    for (int i = 0; i < length; i++) {
      if (predicate(this[i])) return i;
    }
    return -1;
  }
}
