import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import 'lead_detail.dart';

class FollowupDetailScreen extends StatefulWidget {
  final FollowUp followup;
  final Lead? lead;
  final Function(FollowUp)? onFollowupUpdated;
  final Function(String)? onFollowupDeleted;

  const FollowupDetailScreen({
    super.key,
    required this.followup,
    this.lead,
    this.onFollowupUpdated,
    this.onFollowupDeleted,
  });

  @override
  State<FollowupDetailScreen> createState() => _FollowupDetailScreenState();
}

class _FollowupDetailScreenState extends State<FollowupDetailScreen> {
  late FollowUp currentFollowup;
  late bool isCompleted;
  late List<String> pendingDocs;
  late TextEditingController _remarkController;
  final TextEditingController _newDocController = TextEditingController();
  bool _isEditingRemark = false;

  @override
  void initState() {
    super.initState();
    currentFollowup = widget.followup;
    isCompleted = widget.followup.isCompleted;
    pendingDocs = List.from(widget.followup.pendingDocuments);
    _remarkController = TextEditingController(text: widget.followup.remark);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _newDocController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $hour:$min $ampm';
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
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
      'Hello $name, following up regarding your loan inquiry with Eligible CRM.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _triggerTestReminder() async {
    final notifId = currentFollowup.id.hashCode.abs() % 100000;
    final timeStr = _formatDate(currentFollowup.dateTime);
    final title = '⏰ Follow-up Due: ${currentFollowup.leadName}';
    final body = currentFollowup.remark.isNotEmpty
        ? 'Follow-up scheduled for $timeStr\n${currentFollowup.remark}'
        : 'Follow-up scheduled for $timeStr';

    await PushNotificationService.instance.showFollowupReminderNotification(
      id: notifId,
      title: title,
      body: body,
      payload: currentFollowup.leadId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ 2s vibration reminder notification sent!'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _saveUpdatedFollowup() {
    final updated = currentFollowup.copyWith(
      isCompleted: isCompleted,
      remark: _remarkController.text.trim(),
      pendingDocuments: pendingDocs,
    );
    setState(() {
      currentFollowup = updated;
    });
    widget.onFollowupUpdated?.call(updated);
  }

  void _confirmDelete() {
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
            'Are you sure you want to delete follow-up #${currentFollowup.followupNumber} for ${currentFollowup.leadName}? Scheduled reminder notifications will be cancelled.',
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
                final notifId = currentFollowup.id.hashCode.abs() % 100000;
                await PushNotificationService.instance.cancelNotification(notifId);

                widget.onFollowupDeleted?.call(currentFollowup.id);
                if (mounted) {
                  Navigator.pop(context, currentFollowup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Follow-up #${currentFollowup.followupNumber} deleted'),
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
    final isDueToday = _isToday(currentFollowup.dateTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Follow-up #${currentFollowup.followupNumber}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete Follow-up',
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Scheduled Timing Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDueToday ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                  width: isDueToday ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          currentFollowup.followupNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        )
                      else if (isDueToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Due Today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Upcoming',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatDate(currentFollowup.dateTime),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCompleted ? 'Follow-up marked as completed' : 'Mark follow-up as completed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        ),
                      ),
                      Switch(
                        value: isCompleted,
                        activeColor: const Color(0xFF16A34A),
                        onChanged: (val) {
                          setState(() {
                            isCompleted = val;
                          });
                          _saveUpdatedFollowup();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Customer Contact Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUSTOMER CONTACT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentFollowup.leadName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (currentFollowup.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      currentFollowup.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _makeCall(currentFollowup.phone),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _openWhatsApp(currentFollowup.phone, name: currentFollowup.leadName),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Loan Inquiry Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INQUIRY DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Loan Category', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentFollowup.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentFollowup.requiredAmount != null && currentFollowup.requiredAmount! > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Required', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text(
                          '₹${(currentFollowup.requiredAmount! >= 100000 ? "${(currentFollowup.requiredAmount! / 100000).toStringAsFixed(2)} Lakhs" : currentFollowup.requiredAmount!.toStringAsFixed(0))}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ],
                  if (widget.lead != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(double.infinity, 38),
                      ),
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: const Text('View Full Lead Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeadDetailsScreen(lead: widget.lead!),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Calling Notes & Discussion Remark
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CALLING DISCUSSION REMARKS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      IconButton(
                        tooltip: _isEditingRemark ? 'Save' : 'Edit',
                        icon: Icon(
                          _isEditingRemark ? Icons.check_rounded : Icons.edit_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        onPressed: () {
                          if (_isEditingRemark) {
                            _saveUpdatedFollowup();
                          }
                          setState(() {
                            _isEditingRemark = !_isEditingRemark;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isEditingRemark) ...[
                    TextField(
                      controller: _remarkController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter discussion notes...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _saveUpdatedFollowup();
                        setState(() {
                          _isEditingRemark = false;
                        });
                      },
                      child: const Text('Save Remark', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFEF3C7)),
                      ),
                      child: Text(
                        _remarkController.text.isNotEmpty
                            ? _remarkController.text
                            : 'No remarks recorded yet. Tap edit icon above to add discussion notes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _remarkController.text.isNotEmpty ? const Color(0xFF78350F) : const Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Pending Documents Checklist
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PENDING DOCUMENTS (${pendingDocs.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (pendingDocs.isNotEmpty)
                        Text(
                          '${pendingDocs.length} pending',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (pendingDocs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text('All documents received!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                        ],
                      ),
                    )
                  else
                    ...pendingDocs.map(
                      (doc) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                doc,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Mark received',
                              icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
                              onPressed: () {
                                setState(() {
                                  pendingDocs.remove(doc);
                                });
                                _saveUpdatedFollowup();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newDocController,
                          decoration: InputDecoration(
                            hintText: 'Add pending document requirement...',
                            hintStyle: const TextStyle(fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final text = _newDocController.text.trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              pendingDocs.add(text);
                              _newDocController.clear();
                            });
                            _saveUpdatedFollowup();
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Notification Reminder Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notification Reminder Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                        SizedBox(height: 2),
                        Text('2-second continuous vibration set for scheduled date & time', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF92400E),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _triggerTestReminder,
                    child: const Text('Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

