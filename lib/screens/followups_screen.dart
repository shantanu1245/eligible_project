import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import 'followup_detail_screen.dart';
import '../widgets/skeleton_loading.dart';

class FollowupsScreen extends StatefulWidget {
  final List<Lead> leads;
  final bool isLoading;
  final Function(Lead)? onLeadUpdated;

  const FollowupsScreen({
    super.key,
    this.leads = const [],
    this.isLoading = false,
    this.onLeadUpdated,
  });

  @override
  State<FollowupsScreen> createState() => _FollowupsScreenState();
}

class _FollowupsScreenState extends State<FollowupsScreen> {
  late List<FollowUp> followups;
  String _selectedFilter = 'All'; // 'All', 'Today', 'Upcoming', 'Completed'

  @override
  void initState() {
    super.initState();
    _buildFollowupsFromLeads();
  }

  @override
  void didUpdateWidget(covariant FollowupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads != widget.leads) {
      _buildFollowupsFromLeads();
    }
  }

  void _buildFollowupsFromLeads() {
    final List<FollowUp> items = [];
    final now = DateTime.now();

    for (int i = 0; i < widget.leads.length; i++) {
      final lead = widget.leads[i];
      if (lead.status == LeadStatus.lost) continue;

      if (lead.followUps.isNotEmpty) {
        items.addAll(lead.followUps);
      } else {
        // Create an initial structured follow-up for the active lead
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

    // Sort by scheduled date
    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    setState(() {
      followups = items;
    });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$min $ampm';
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
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

  /// Schedule notification reminder for the agent at the exact follow-up date and time
  Future<void> _scheduleFollowupNotification(FollowUp item) async {
    final notifId = item.id.hashCode.abs() % 100000;
    final timeStr = _formatDate(item.dateTime);
    final title = '⏰ Follow-up Due: ${item.leadName}';
    final body = item.remark.isNotEmpty
        ? 'Follow-up scheduled for $timeStr\nRemark: ${item.remark}'
        : 'Follow-up scheduled for $timeStr';

    await PushNotificationService.instance.scheduleFollowupNotification(
      id: notifId,
      title: title,
      body: body,
      scheduledDate: item.dateTime,
      payload: item.leadId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ 2s vibration reminder scheduled for $timeStr (${item.leadName})'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Delete a follow-up with confirmation dialog and cancel its notification
  void _confirmDeleteFollowup(FollowUp item) {
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
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Delete Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete follow-up #${item.followupNumber} for ${item.leadName}? This will also cancel any scheduled reminder alerts.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final notifId = item.id.hashCode.abs() % 100000;
                await PushNotificationService.instance.cancelNotification(notifId);

                setState(() {
                  followups.removeWhere((f) => f.id == item.id);
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Follow-up #${item.followupNumber} deleted successfully'),
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

  @override
  Widget build(BuildContext context) {
    final todayItems = followups.where((f) => !f.isCompleted && _isToday(f.dateTime)).toList();
    final upcomingItems =
        followups.where((f) => !f.isCompleted && !_isToday(f.dateTime) && f.dateTime.isAfter(DateTime.now())).toList();
    final completedItems = followups.where((f) => f.isCompleted).toList();

    List<FollowUp> displayedList = [];
    if (_selectedFilter == 'Today') {
      displayedList = todayItems;
    } else if (_selectedFilter == 'Upcoming') {
      displayedList = upcomingItems;
    } else if (_selectedFilter == 'Completed') {
      displayedList = completedItems;
    } else {
      displayedList = followups;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-ups',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              '${followups.where((f) => !f.isCompleted).length} pending • Unique Date & Number Tracking',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: widget.isLoading
          ? const FollowupsScreenSkeleton()
          : followups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_available_outlined,
                          size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No follow-ups scheduled',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All ${widget.leads.length} database leads are up to date',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    _buildSummary(
                      todayItems.length,
                      upcomingItems.length,
                      completedItems.length,
                    ),
                    const SizedBox(height: 14),
                    _buildFilterPills(
                      todayItems.length,
                      upcomingItems.length,
                      completedItems.length,
                    ),
                    const SizedBox(height: 16),
                    if (displayedList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'No $_selectedFilter follow-ups found',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      )
                    else
                      ...displayedList.map((fup) => _followupCard(fup)),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFollowupDialog(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Follow-up',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSummary(int todayCount, int upcomingCount, int completedCount) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard('Today', '$todayCount', Icons.today_outlined,
              const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard('Upcoming', '$upcomingCount', Icons.event_outlined,
              AppTheme.primary, const Color(0xFFEFF6FF)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard('Done', '$completedCount',
              Icons.task_alt_outlined, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(int todayCount, int upcomingCount, int completedCount) {
    final pills = [
      {'label': 'All', 'count': followups.length},
      {'label': 'Today', 'count': todayCount},
      {'label': 'Upcoming', 'count': upcomingCount},
      {'label': 'Completed', 'count': completedCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pills.map((p) {
          final isSelected = _selectedFilter == p['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${p['label']} (${p['count']})'),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = p['label'] as String);
              },
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
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
    );
  }

  Widget _followupCard(FollowUp item) {
    Lead? lead;
    try {
      lead = widget.leads.firstWhere((l) => l.id == item.leadId);
    } catch (_) {}

    final isToday = _isToday(item.dateTime);

    return Dismissible(
      key: ValueKey('fup_${item.id}_${item.followupNumber}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Complete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.check, color: Colors.white),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() {
          final idx = followups.indexWhere((f) => f.id == item.id);
          if (idx != -1) {
            followups[idx] = followups[idx].copyWith(isCompleted: true);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.leadName} follow-up marked as completed'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isCompleted
                ? const Color(0xFFBBF7D0)
                : isToday
                    ? const Color(0xFFFECACA)
                    : AppTheme.border,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowupDetailScreen(
                  followup: item,
                  lead: lead,
                  onFollowupUpdated: (updatedFup) {
                    setState(() {
                      final idx = followups.indexWhere((f) => f.id == updatedFup.id);
                      if (idx != -1) {
                        followups[idx] = updatedFup;
                      }
                    });
                  },
                  onFollowupDeleted: (deletedId) {
                    setState(() {
                      followups.removeWhere((f) => f.id == deletedId);
                    });
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Simple ID, Status & Delete Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag_rounded, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                item.followupNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          )
                        else if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Due Today',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Delete Follow-up',
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 18),
                          onPressed: () => _confirmDeleteFollowup(item),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lead Name (No Avatar!) & Actions (Call & WhatsApp)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.leadName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              if (item.category.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.phone.isNotEmpty) ...[
                          IconButton(
                            tooltip: 'Call Customer',
                            icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 18),
                            onPressed: () => _makeCall(item.phone),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFDCFCE7),
                              padding: const EdgeInsets.all(7),
                              minimumSize: const Size(34, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Chat on WhatsApp',
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF059669), size: 18),
                            onPressed: () => _openWhatsApp(item.phone, name: item.leadName),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFD1FAE5),
                              padding: const EdgeInsets.all(7),
                              minimumSize: const Size(34, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Scheduled Date & Time (Minimum Data card)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatDate(item.dateTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (item.requiredAmount != null && item.requiredAmount! > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${(item.requiredAmount! >= 100000 ? "${(item.requiredAmount! / 100000).toStringAsFixed(1)}L" : item.requiredAmount!.toStringAsFixed(0))}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFollowupDialog(BuildContext context, {Lead? preselectedLead}) {
    Lead? selectedLead = preselectedLead ?? (widget.leads.isNotEmpty ? widget.leads.first : null);
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);

    final remarkController = TextEditingController();
    final customDocController = TextEditingController();

    // Generate simple unique follow-up number: FUP-XXX
    final uniqueFollowupNum =
        'FUP-${(followups.length + 1).toString().padLeft(3, '0')}';

    final availableDocuments = [
      'Aadhaar Card',
      'PAN Card',
      '6M Bank Statement',
      '3M Salary Slips',
      '2Y ITR / Form 16',
      'Property Title Deeds',
      'GST / Business Registration',
      'Electricity Bill',
    ];

    final Set<String> chosenDocs = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final scheduledDateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
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
                        const Expanded(
                          child: Text(
                            'Schedule Follow-up',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              uniqueFollowupNum,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Unique follow-up record with calling notes & pending documents',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 1. Lead Selection & Auto Populate
                    const Text(
                      'SELECT LEAD (AUTO-POPULATES DETAILS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Lead>(
                          isExpanded: true,
                          value: selectedLead,
                          hint: const Text('Choose customer lead'),
                          items: widget.leads.map((l) {
                            return DropdownMenuItem<Lead>(
                              value: l,
                              child: Text(
                                '${l.name} • ${l.categoryDisplay} (${l.phone})',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (Lead? val) {
                            if (val != null) {
                              setModalState(() => selectedLead = val);
                            }
                          },
                        ),
                      ),
                    ),

                    if (selectedLead != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Populated: ${selectedLead!.categoryDisplay} • ${selectedLead!.phone} • ₹${selectedLead!.requiredLoan != null ? "${(selectedLead!.requiredLoan! / 100000).toStringAsFixed(1)}L" : "N/A"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 2. Unique Date & Time Picker
                    const Text(
                      'FOLLOW-UP DATE & TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setModalState(() => selectedTime = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_outlined,
                                      size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      selectedTime.format(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. Calling Remark Field
                    const Text(
                      'ADD REMARK (CALLING DISCUSSION NOTES)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'E.g. Called customer at 11 AM. Customer asked to call back in evening. Agreed on 8.5% ROI, requested salary slip and 6M statement.',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. Pending Document Checklist After Calling
                    const Text(
                      'PENDING DOCUMENTS AFTER CALLING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableDocuments.map((doc) {
                        final isDocChosen = chosenDocs.contains(doc);
                        return FilterChip(
                          label: Text(doc),
                          selected: isDocChosen,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                chosenDocs.add(doc);
                              } else {
                                chosenDocs.remove(doc);
                              }
                            });
                          },
                          selectedColor: const Color(0xFFFEE2E2),
                          checkmarkColor: const Color(0xFFDC2626),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isDocChosen ? FontWeight.w700 : FontWeight.w500,
                            color: isDocChosen
                                ? const Color(0xFFDC2626)
                                : AppTheme.textSecondary,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isDocChosen
                                ? const Color(0xFFDC2626)
                                : AppTheme.border,
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // Custom Document adder
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customDocController,
                            decoration: InputDecoration(
                              hintText: 'Add other pending doc (e.g. Rent Agreement)',
                              hintStyle: const TextStyle(fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF475569),
                            minimumSize: const Size(60, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final text = customDocController.text.trim();
                            if (text.isNotEmpty) {
                              setModalState(() {
                                availableDocuments.add(text);
                                chosenDocs.add(text);
                                customDocController.clear();
                              });
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: selectedLead == null
                            ? null
                            : () {
                                final newFup = FollowUp(
                                  id: 'fup_${DateTime.now().millisecondsSinceEpoch}',
                                  followupNumber: uniqueFollowupNum,
                                  leadId: selectedLead!.id,
                                  leadName: selectedLead!.name,
                                  phone: selectedLead!.phone,
                                  category: selectedLead!.categoryDisplay,
                                  requiredAmount: selectedLead!.requiredLoan ??
                                      selectedLead!.propertyCost,
                                  remark: remarkController.text.trim(),
                                  dateTime: scheduledDateTime,
                                  pendingDocuments: chosenDocs.toList(),
                                );

                                setState(() {
                                  followups.insert(0, newFup);
                                });

                                Navigator.pop(ctx);

                                // Schedule 2-second vibration reminder notification for the exact scheduled date and time
                                _scheduleFollowupNotification(newFup);
                              },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Save Follow-up Record',
                          style: TextStyle(
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
}