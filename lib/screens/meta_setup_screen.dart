import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class MetaSetupScreen extends StatefulWidget {
  const MetaSetupScreen({super.key});

  @override
  State<MetaSetupScreen> createState() => _MetaSetupScreenState();
}

class _MetaSetupScreenState extends State<MetaSetupScreen> {
  final BackendService _backend = BackendService();

  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();

  bool _obscureToken = true;
  bool _isDiscovering = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  String? _discoveryError;

  // Discovered assets
  Map<String, dynamic>? _connectedUser;
  List<Map<String, dynamic>> _adAccounts = [];
  List<Map<String, dynamic>> _pages = [];
  List<Map<String, dynamic>> _forms = [];

  // Selected values
  String? _selectedAdAccountId;
  String? _selectedAdAccountName;
  String? _selectedPageId;
  String? _selectedPageName;
  String? _selectedFormId;

  bool _hasActiveConnection = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final status = await _backend.getMetaConfig();
    if (mounted && status.isNotEmpty) {
      final config = status['config'] as Map<String, dynamic>?;
      setState(() {
        _hasActiveConnection = status['configured'] == true;
        if (config != null) {
          _selectedAdAccountId = config['adAccountId'];
          _selectedAdAccountName = config['adAccountName'];
          _selectedPageId = config['pageId'];
          _selectedPageName = config['pageName'];
        }
        if (status['maskedToken'] != null && _tokenController.text.isEmpty) {
          _tokenController.text = status['maskedToken'];
        }
      });
    }
  }

  Future<void> _discoverAssets() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or paste your Meta Access Token'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isDiscovering = true;
      _discoveryError = null;
    });

    final res = await _backend.discoverMetaAssets(token);

    if (mounted) {
      setState(() => _isDiscovering = false);

      if (res['success'] == true) {
        final adAccs = (res['adAccounts'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final pgs = (res['pages'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final frms = (res['forms'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          _connectedUser = res['user'] != null ? Map<String, dynamic>.from(res['user']) : null;
          _adAccounts = adAccs;
          _pages = pgs;
          _forms = frms;

          // Default selection
          if (adAccs.isNotEmpty) {
            _selectedAdAccountId = adAccs.first['id'];
            _selectedAdAccountName = adAccs.first['name'];
          }
          if (pgs.isNotEmpty) {
            _selectedPageId = pgs.first['id'];
            _selectedPageName = pgs.first['name'];
          }
          if (frms.isNotEmpty) {
            _selectedFormId = frms.first['id'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Discovered ${_adAccounts.length} Ad Accounts and ${_pages.length} Pages!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        setState(() {
          _discoveryError = res['message'] ?? 'Could not validate Meta Access Token';
        });
      }
    }
  }

  Future<void> _saveAndConnect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Token is required to connect'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final res = await _backend.saveMetaConfig(
      accessToken: token,
      adAccountId: _selectedAdAccountId,
      adAccountName: _selectedAdAccountName,
      pageId: _selectedPageId,
      pageName: _selectedPageName,
      appSecret: _secretController.text.trim().isNotEmpty ? _secretController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (res['success'] == true) {
        setState(() => _hasActiveConnection = true);
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to connect Meta account'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _syncLeadsNow() async {
    setState(() => _isSyncing = true);
    final res = await _backend.syncMetaLeads(formId: _selectedFormId);
    if (mounted) {
      setState(() => _isSyncing = false);
      final msg = res['message'] ?? (res['success'] == true ? 'Synced leads successfully!' : 'Sync failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 10),
            Text('Meta Account Connected!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Meta Ads account is now connected and saved to Firebase Realtime Database. All campaigns and leads will be managed through this account.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📄 Page: ${_selectedPageName ?? _selectedPageId ?? 'Selected'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('📋 Ad Account: ${_selectedAdAccountName ?? _selectedAdAccountId ?? 'Selected'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _syncLeadsNow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Leads Now'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Meta Account Setup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _buildConnectionHeader(),
          const SizedBox(height: 16),
          _buildTokenInputCard(),
          if (_connectedUser != null || _adAccounts.isNotEmpty || _pages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDiscoveredSelectorsCard(),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 16),
          _buildWebhookGuideCard(),
        ],
      ),
    );
  }

  Widget _buildConnectionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meta Lead Ads & Marketing API',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  _hasActiveConnection
                      ? 'Connected: ${_selectedPageName ?? 'Active Meta Page'}'
                      : 'Not configured yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasActiveConnection ? const Color(0xFF16A34A) : AppTheme.textSecondary,
                    fontWeight: _hasActiveConnection ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hasActiveConnection ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasActiveConnection ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
              ),
            ),
            child: Text(
              _hasActiveConnection ? 'Live Connected' : 'Setup Required',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _hasActiveConnection ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: Meta Access Token',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste your Meta System User or User Access Token. It should include permissions: leads_retrieval, ads_management, pages_manage_ads.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Token Field
          TextFormField(
            controller: _tokenController,
            obscureText: _obscureToken,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: 'Meta Access Token *',
              hintText: 'EAAB...',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureToken = !_obscureToken),
                    tooltip: 'Toggle visibility',
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste_outlined),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        setState(() => _tokenController.text = data!.text!);
                      }
                    },
                    tooltip: 'Paste from clipboard',
                  ),
                ],
              ),
            ),
          ),

          if (_discoveryError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _discoveryError!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isDiscovering ? null : _discoverAssets,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isDiscovering
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.travel_explore_outlined),
              label: Text(
                _isDiscovering ? 'Discovering Meta Accounts...' : 'Verify & Discover Accounts',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredSelectorsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Step 2: Select Connected Assets',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              if (_connectedUser != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '👤 ${_connectedUser!['name']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Ad Account Dropdown
          if (_adAccounts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedAdAccountId,
              decoration: const InputDecoration(
                labelText: 'Target Ad Account',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: _adAccounts.map((a) {
                return DropdownMenuItem<String>(
                  value: a['id'],
                  child: Text('${a['name']} (${a['currency']})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _adAccounts.firstWhere((a) => a['id'] == val);
                  setState(() {
                    _selectedAdAccountId = val;
                    _selectedAdAccountName = found['name'];
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // Page Dropdown
          if (_pages.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedPageId,
              decoration: const InputDecoration(
                labelText: 'Target Facebook Page',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: _pages.map((p) {
                return DropdownMenuItem<String>(
                  value: p['id'],
                  child: Text('${p['name']} (${p['category'] ?? 'Page'})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _pages.firstWhere((p) => p['id'] == val);
                  setState(() {
                    _selectedPageId = val;
                    _selectedPageName = found['name'];
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // Lead Form Dropdown
          if (_forms.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedFormId,
              decoration: const InputDecoration(
                labelText: 'Default Lead Form for Sync',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              items: _forms.map((f) {
                return DropdownMenuItem<String>(
                  value: f['id'],
                  child: Text('${f['name']} (${f['leadsCount']} leads)', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFormId = val);
              },
            ),
            const SizedBox(height: 12),
          ],

          // Optional App Secret
          TextFormField(
            controller: _secretController,
            decoration: const InputDecoration(
              labelText: 'App Secret (Optional for Webhook Security)',
              hintText: 'e.g. 9b88c7f...',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAndConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_done_outlined),
            label: Text(
              _isSaving ? 'Connecting & Saving...' : 'Save & Connect to CRM',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        if (_hasActiveConnection) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isSyncing ? null : _syncLeadsNow,
              icon: _isSyncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: const Text('Sync All Leads from Meta Now'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWebhookGuideCard() {
    const callbackUrl = 'https://eligible-backend.onrender.com/api/webhooks/meta';
    const verifyToken = 'eligible_crm_secure_verify_token_2026';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.webhook, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Live Webhook for Real-Time Leads',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'To receive leads instantly whenever someone submits your Meta Lead Form, add these in Meta for Developers -> App Dashboard -> Webhooks -> Page:',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          _copyableBox('Callback URL', callbackUrl),
          const SizedBox(height: 10),
          _copyableBox('Verify Token', verifyToken),
        ],
      ),
    );
  }

  Widget _copyableBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppTheme.primary),
            onPressed: () => _copyToClipboard(value, label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy $label',
          ),
        ],
      ),
    );
  }
}
