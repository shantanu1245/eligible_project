import '../widgets/admin_guard.dart';
import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class RecycleBinScreen extends StatefulWidget {
  final UserModel? currentUser;
  final Function(Lead)? onLeadRestored;

  const RecycleBinScreen({
    super.key,
    this.currentUser,
    this.onLeadRestored,
  });

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _binLeads = [];

  @override
  void initState() {
    super.initState();
    if (AdminGuard.isCurrentAdmin) {
      _fetchBinLeads();
    }
  }

  Future<void> _fetchBinLeads() async {
    setState(() => _isLoading = true);
    try {
      final list = await BackendService().getBinLeads();
      if (mounted) {
        setState(() {
          _binLeads = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateDaysRemaining(Map<String, dynamic> lead) {
    final purgeAtStr = lead['purgeAt']?.toString();
    final deletedAtStr = lead['deletedAt']?.toString();
    final now = DateTime.now();

    if (purgeAtStr != null) {
      final purgeAt = DateTime.tryParse(purgeAtStr);
      if (purgeAt != null) {
        final remaining = purgeAt.difference(now).inDays;
        return remaining < 0 ? 0 : remaining;
      }
    }

    if (deletedAtStr != null) {
      final deletedAt = DateTime.tryParse(deletedAtStr);
      if (deletedAt != null) {
        final daysSince = now.difference(deletedAt).inDays;
        final remaining = 30 - daysSince;
        return remaining < 0 ? 0 : remaining;
      }
    }

    return 30;
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recently';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'Recently';
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hr = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $hr:$min';
  }

  Future<void> _restoreLead(Map<String, dynamic> leadMap) async {
    final id = leadMap['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final name = leadMap['name']?.toString() ?? 'Lead';

    setState(() {
      _binLeads.removeWhere((l) => l['id'] == id);
    });

    try {
      final res = await BackendService().restoreLeadFromBin(id, leadData: leadMap);
      if (res['data'] is Map) {
        try {
          final restoredLead = Lead.fromJson(Map<String, dynamic>.from(res['data']));
          widget.onLeadRestored?.call(restoredLead);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('♻️ Restored "$name" to active leads'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore lead: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmPermanentDelete(Map<String, dynamic> leadMap) async {
    final id = leadMap['id']?.toString() ?? '';
    final name = leadMap['name']?.toString() ?? 'Lead';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Permanent Delete', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"?\n\nThis lead cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _binLeads.removeWhere((l) => l['id'] == id);
      });
      await BackendService().permanentDeleteFromBin(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💥 Permanently deleted "$name"'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmEmptyBin() async {
    if (_binLeads.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Empty Recycle Bin', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${_binLeads.length} leads in the bin?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Delete All (${_binLeads.length})'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _binLeads.clear();
      });
      await BackendService().emptyBin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💥 Recycle Bin emptied successfully'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      title: 'Recycle Bin Restricted',
      message: 'Viewing and restoring deleted leads is restricted strictly to Administrators.',
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Recycle Bin', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_binLeads.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmEmptyBin,
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 18),
              label: const Text(
                'Empty Bin',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBinLeads,
        color: AppTheme.primary,
        child: Column(
          children: [
            // 30-day retention info header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Deleted leads are kept in the bin for 30 days before being permanently purged.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _binLeads.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _binLeads.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) => _buildBinLeadTile(_binLeads[idx]),
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, size: 36, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 14),
              const Text(
                'Recycle Bin is Empty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No deleted leads in the last 30 days',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBinLeadTile(Map<String, dynamic> lead) {
    final name = lead['name']?.toString() ?? 'Unnamed Lead';
    final phone = lead['phone']?.toString() ?? lead['mobile']?.toString() ?? '';
    final loanType = lead['loanType']?.toString() ?? lead['category']?.toString() ?? 'Loan';
    final deletedAt = lead['deletedAt']?.toString();
    final daysRemaining = _calculateDaysRemaining(lead);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⏳ $daysRemaining days left',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  loanType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deleted: ${_formatDate(deletedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _confirmPermanentDelete(lead),
                icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Color(0xFFDC2626)),
                label: const Text(
                  'Delete Forever',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _restoreLead(lead),
                icon: const Icon(Icons.restore_rounded, size: 14),
                label: const Text('Restore Lead', style: TextStyle(fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
