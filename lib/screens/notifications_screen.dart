import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import 'lead_detail.dart';

class NotificationsScreen extends StatefulWidget {
  final List<Lead> leads;
  final Function(List<Lead>)? onLeadsUpdated;

  const NotificationsScreen({
    super.key,
    this.leads = const [],
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
  bool _isSendingTest = false;
  List<Map<String, dynamic>> _allNotifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final res = await _backend.getNotifications();
    if (mounted) {
      final list = (res['data'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _allNotifications = list;
        _unreadCount = res['unreadCount'] ?? list.where((n) => n['read'] != true).length;
        _isLoading = false;
      });
    }
  }

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
    await _backend.markAllNotificationsRead();
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

  Future<void> _triggerTestAlert() async {
    setState(() => _isSendingTest = true);
    final res = await _backend.sendTestNotification();
    if (mounted) {
      setState(() => _isSendingTest = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test lead notification sent to Admin & Sales topics!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        _loadNotifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Could not send test notification'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _openLeadDetail(Map<String, dynamic> notif) {
    final leadId = notif['leadId'];
    Lead? matchedLead;

    try {
      matchedLead = widget.leads.firstWhere((l) => l.id == leadId);
    } catch (_) {
      // Create preview lead from notification data if not found in list
      matchedLead = Lead(
        id: leadId?.toString() ?? 'lead_notif_${DateTime.now().millisecondsSinceEpoch}',
        name: notif['leadName'] ?? 'Lead from Notification',
        phone: notif['leadPhone'] ?? '',
        email: '',
        source: notif['source'] ?? 'Meta Ads',
        campaign: notif['budget'] != null ? 'Budget: ${notif['budget']}' : 'Meta Ad Campaign',
        status: LeadStatus.newLead,
        assignedTo: notif['assignedTo'] ?? '',
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
        .where((n) => n['targetRole'] == 'sales_agent')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notification Center',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadNotifications,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'mark_all_read') _markAllRead();
              if (val == 'test_alert') _triggerTestAlert();
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
              const PopupMenuItem(
                value: 'test_alert',
                child: Row(
                  children: [
                    Icon(Icons.bolt, size: 18, color: Color(0xFF1877F2)),
                    SizedBox(width: 10),
                    Text('Send Test Lead Alert'),
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
          tabs: [
            Tab(text: 'All (${_allNotifications.length})'),
            Tab(text: 'Admin (${adminNotifs.length})'),
            Tab(text: 'Sales (${salesNotifs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(_allNotifications),
                _buildNotificationList(adminNotifs, emptyLabel: 'No Admin alerts yet'),
                _buildNotificationList(salesNotifs, emptyLabel: 'No Sales Agent alerts yet'),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _unreadCount == 0 ? null : _markAllRead,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All Read'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSendingTest ? null : _triggerTestAlert,
                  icon: _isSendingTest
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.add_alert, size: 16),
                  label: const Text('Send Test Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
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
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSendingTest ? null : _triggerTestAlert,
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('Trigger Test Lead Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
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
                      color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.trending_up,
                      color: isAdmin ? const Color(0xFF1877F2) : const Color(0xFFD97706),
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
                                color: isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin ? 'ADMIN ALERT' : 'SALES TEAM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isAdmin ? const Color(0xFF1E40AF) : const Color(0xFF92400E),
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
                child: Row(
                  children: [
                    if (leadName.isNotEmpty) ...[
                      const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        leadName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (budget.isNotEmpty) ...[
                      const Icon(Icons.currency_rupee, size: 13, color: Color(0xFF16A34A)),
                      Text(
                        budget,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Spacer(),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                  const SizedBox(width: 8),
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
