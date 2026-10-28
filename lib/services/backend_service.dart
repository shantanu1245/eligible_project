import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  _CacheEntry(this.data, {Duration ttl = const Duration(minutes: 3)})
      : expiresAt = DateTime.now().add(ttl);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal() {
    _initBaseUrl();
  }

  static const String _defaultCloudUrl = 'https://eligible-backend.onrender.com/api';
  String _baseUrl = _defaultCloudUrl;

  // In-memory client cache for lightning speed instantaneous responses (0ms)
  final Map<String, _CacheEntry> _cache = {};

  void clearMetaCache() {
    _cache.clear();
    debugPrint('[BackendService] 🧹 Meta client cache cleared');
  }

  void _initBaseUrl() {
    _baseUrl = _defaultCloudUrl;
    // Asynchronously and non-blockingly check if local server is active (without holding up UI requests)
    _probeLocalhostAsync();
  }

  void _probeLocalhostAsync() async {
    if (!kDebugMode && !kIsWeb) return;
    final localHost = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? 'http://10.0.2.2:5000/api'
        : 'http://localhost:5000/api';
    try {
      final res = await http.get(Uri.parse('$localHost/ping')).timeout(const Duration(milliseconds: 350));
      if (res.statusCode == 200) {
        _baseUrl = localHost;
        debugPrint('[BackendService] 🚀 Local backend active, switched to: $_baseUrl');
      }
    } catch (_) {
      // Localhost offline, stay on cloud backend at lightning speed
    }
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  Timer? _keepAliveTimer;

  /// Start automatic live server pinger in Flutter
  void startKeepAlivePinger({Duration interval = const Duration(minutes: 5)}) {
    _keepAliveTimer?.cancel();
    // Fire immediate ping to warm up backend on app launch
    pingServer();
    _keepAliveTimer = Timer.periodic(interval, (_) {
      pingServer();
    });
    debugPrint('[BackendService] 💓 Live server keep-alive pinger started (${interval.inMinutes}m interval)');
  }

  /// Stop keep-alive pinger
  void stopKeepAlivePinger() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Fast ping to instance to keep it active and awake
  Future<Map<String, dynamic>> pingServer() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/ping'),
            headers: {'X-Purpose': 'flutter-keep-alive'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint('[BackendService] 💓 Server Awake: ${data['message']} (uptime: ${data['uptimeSeconds']}s)');
        return data;
      }
    } catch (e) {
      debugPrint('[BackendService] ⚠️ Ping note: $e');
      final alternate = _baseUrl.contains('localhost') || _baseUrl.contains('10.0.2.2')
          ? 'https://eligible-backend.onrender.com/api'
          : (kIsWeb || defaultTargetPlatform != TargetPlatform.android ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api');
      try {
        final altRes = await http.get(Uri.parse('$alternate/ping')).timeout(const Duration(seconds: 4));
        if (altRes.statusCode == 200) {
          _baseUrl = alternate;
          debugPrint('[BackendService] 🔄 Auto-switched to active backend: $_baseUrl');
          return jsonDecode(altRes.body);
        }
      } catch (_) {}
    }
    return {'status': 'error'};
  }

  /// Fetch keep-alive diagnostics from backend
  Future<Map<String, dynamic>> getKeepAliveStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/keep-alive'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'success': false};
  }

  /// Check server health
  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get status of Meta and Firebase integrations
  Future<Map<String, dynamic>> getIntegrationStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/meta/status'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? {};
      }
    } catch (e) {
      debugPrint('[BackendService] getIntegrationStatus error: $e');
    }
    return {
      'server': {'status': 'offline'},
      'firebase': {'connected': false, 'mode': 'local_storage'},
      'meta': {'configured': false, 'mode': 'simulation'},
    };
  }

  /// Test Meta API connection
  Future<Map<String, dynamic>> testMetaConnection() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/meta/test-connection'))
          .timeout(const Duration(seconds: 6));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch all campaigns from backend (Firebase + Meta live sync)
  Future<List<Map<String, dynamic>>> getCampaigns() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/campaigns'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getCampaigns error: $e');
    }
    return [];
  }

  /// Create a new Meta Ads Campaign from Eligible CRM
  Future<Map<String, dynamic>> createCampaign({
    required String name,
    required double dailyBudget,
    String platform = 'Facebook & Instagram',
    List<String> targetLocations = const ['IN'],
    String? headline,
    String? bodyText,
    String? formId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/campaigns'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'dailyBudget': dailyBudget,
              'platform': platform,
              'targetLocations': targetLocations,
              'headline': headline,
              'bodyText': bodyText,
              'formId': formId,
              'status': 'ACTIVE',
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      debugPrint('[BackendService] createCampaign error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Toggle Campaign Status (ACTIVE / PAUSED)
  Future<bool> toggleCampaignStatus(String campaignId, String status) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/campaigns/$campaignId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Safe HTTP GET with auto-discovery and seamless host fallback (Local <-> Cloud)
  Future<http.Response?> _safeGet(String path, {Map<String, String>? query, Duration timeout = const Duration(seconds: 5)}) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl/$cleanPath').replace(queryParameters: query?.isNotEmpty == true ? query : null);
    try {
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode == 200) return res;
    } catch (e) {
      debugPrint('[BackendService] Request to $_baseUrl/$cleanPath note: $e');
    }

    // Try alternate host (local <-> cloud) with fast 3-second timeout
    final alternate = _baseUrl.contains('localhost') || _baseUrl.contains('10.0.2.2')
        ? 'https://eligible-backend.onrender.com/api'
        : (kIsWeb || defaultTargetPlatform != TargetPlatform.android ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api');

    try {
      final altUri = Uri.parse('$alternate/$cleanPath').replace(queryParameters: query?.isNotEmpty == true ? query : null);
      final altRes = await http.get(altUri).timeout(const Duration(seconds: 3));
      if (altRes.statusCode == 200) {
        _baseUrl = alternate;
        debugPrint('[BackendService] 🔄 Auto-switched to active backend: $_baseUrl');
        return altRes;
      }
    } catch (_) {}

    return null;
  }

  /// Retrieve accessible Meta Ad Accounts with client caching
  Future<List<Map<String, dynamic>>> getMetaAccounts({bool forceRefresh = false}) async {
    const cacheKey = 'meta_accounts';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    try {
      final query = forceRefresh ? {'refresh': 'true'} : null;
      final res = await _safeGet('meta/accounts', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cache[cacheKey] = _CacheEntry(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaAccounts error: $e');
    }
    return [];
  }

  /// Retrieve Meta Campaigns with live metrics & date filters with client caching
  Future<List<Map<String, dynamic>>> getMetaCampaigns({
    String? adAccountId,
    String? datePreset,
    String? status,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'meta_campaigns_${adAccountId ?? ""}_${datePreset ?? ""}_${status ?? ""}';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    try {
      final query = <String, String>{};
      if (adAccountId != null) query['adAccountId'] = adAccountId;
      if (datePreset != null) query['datePreset'] = datePreset;
      if (status != null) query['status'] = status;
      if (forceRefresh) query['refresh'] = 'true';

      final res = await _safeGet('meta/campaigns', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cache[cacheKey] = _CacheEntry(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaCampaigns error: $e');
    }
    return [];
  }

  /// Retrieve Meta Ad Sets with client caching
  Future<List<Map<String, dynamic>>> getMetaAdSets({
    String? adAccountId,
    String? campaignId,
    String? datePreset,
    String? status,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'meta_adsets_${adAccountId ?? ""}_${campaignId ?? ""}_${datePreset ?? ""}_${status ?? ""}';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    try {
      final query = <String, String>{};
      if (adAccountId != null) query['adAccountId'] = adAccountId;
      if (campaignId != null) query['campaignId'] = campaignId;
      if (datePreset != null) query['datePreset'] = datePreset;
      if (status != null) query['status'] = status;
      if (forceRefresh) query['refresh'] = 'true';

      final res = await _safeGet('meta/adsets', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cache[cacheKey] = _CacheEntry(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaAdSets error: $e');
    }
    return [];
  }

  /// Retrieve Meta Ads with client caching
  Future<List<Map<String, dynamic>>> getMetaAds({
    String? adAccountId,
    String? campaignId,
    String? adSetId,
    String? datePreset,
    String? status,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'meta_ads_${adAccountId ?? ""}_${campaignId ?? ""}_${adSetId ?? ""}_${datePreset ?? ""}_${status ?? ""}';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    try {
      final query = <String, String>{};
      if (adAccountId != null) query['adAccountId'] = adAccountId;
      if (campaignId != null) query['campaignId'] = campaignId;
      if (adSetId != null) query['adSetId'] = adSetId;
      if (datePreset != null) query['datePreset'] = datePreset;
      if (status != null) query['status'] = status;
      if (forceRefresh) query['refresh'] = 'true';

      final res = await _safeGet('meta/ads', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cache[cacheKey] = _CacheEntry(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaAds error: $e');
    }
    return [];
  }

  /// Retrieve Performance Insights with client caching
  Future<Map<String, dynamic>> getMetaInsights({
    String? adAccountId,
    String level = 'account',
    String? id,
    String datePreset = 'last_30d',
    String? timeIncrement,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'meta_insights_${adAccountId ?? ""}_${level}_${id ?? ""}_${datePreset}_${timeIncrement ?? ""}';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data as Map);
    }

    try {
      final query = <String, String>{
        'level': level,
        'datePreset': datePreset,
      };
      if (adAccountId != null) query['adAccountId'] = adAccountId;
      if (id != null) query['id'] = id;
      if (timeIncrement != null) query['timeIncrement'] = timeIncrement;
      if (forceRefresh) query['refresh'] = 'true';

      final res = await _safeGet('meta/insights', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final result = Map<String, dynamic>.from(data['data'] ?? {});
        _cache[cacheKey] = _CacheEntry(result);
        return result;
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaInsights error: $e');
    }
    return {};
  }

  /// Retrieve Meta Diagnostics & Permissions with client caching
  Future<Map<String, dynamic>> getMetaDiagnostics({bool forceRefresh = false}) async {
    const cacheKey = 'meta_diagnostics';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data as Map);
    }

    try {
      final query = forceRefresh ? {'refresh': 'true'} : null;
      final res = await _safeGet('meta/diagnostics', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final result = Map<String, dynamic>.from(data['data'] ?? {});
        _cache[cacheKey] = _CacheEntry(result);
        return result;
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaDiagnostics error: $e');
    }
    return {};
  }

  /// Retrieve Meta Sync Status with client caching
  Future<Map<String, dynamic>> getMetaSyncStatus({bool forceRefresh = false}) async {
    const cacheKey = 'meta_sync_status';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data as Map);
    }

    try {
      final query = forceRefresh ? {'refresh': 'true'} : null;
      final res = await _safeGet('meta/sync-status', query: query);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final result = Map<String, dynamic>.from(data['data'] ?? {});
        _cache[cacheKey] = _CacheEntry(result);
        return result;
      }
    } catch (_) {}
    return {};
  }

  /// Retrieve Meta Leadgen Forms with client caching
  Future<List<Map<String, dynamic>>> getMetaLeadForms({String? pageId, bool forceRefresh = false}) async {
    final cacheKey = 'meta_leadforms_${pageId ?? ""}';
    if (!forceRefresh && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    try {
      final query = <String, String>{};
      if (pageId != null) query['pageId'] = pageId;
      if (forceRefresh) query['refresh'] = 'true';

      final res = await _safeGet('meta/leadgen-forms', query: query.isNotEmpty ? query : null);
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _cache[cacheKey] = _CacheEntry(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaLeadForms error: $e');
    }
    return [];
  }

  /// Loan Calculator Web App & Database Base URL (default local port 3000)
  String _loanCalculatorUrl = 'http://localhost:3000/api';

  String get loanCalculatorUrl => _loanCalculatorUrl;
  set loanCalculatorUrl(String url) {
    _loanCalculatorUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  /// Firebase Realtime Database REST endpoint where the Loan Calculator website
  /// stores leads directly. Public read — same project config the website uses.
  static const String _firebaseRtdbLeadsUrl =
      'https://eligiblecrmdatabase-default-rtdb.firebaseio.com/leads.json';

  /// Map website/Firebase status values to the CRM's camelCase conventions.
  static String _normalizeLeadStatus(dynamic status) {
    final raw = status?.toString() ?? '';
    final key = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    const statusMap = {
      'new': 'newLead',
      'newlead': 'newLead',
      'contacted': 'contacted',
      'qualified': 'qualified',
      'converted': 'converted',
      'lost': 'lost',
    };
    return statusMap[key] ?? (raw.isNotEmpty ? raw : 'newLead');
  }

  /// Fetch leads from backend AND Firebase Realtime Database, merged & deduped.
  Future<List<Map<String, dynamic>>> getLeads({String? status}) async {
    final merged = <String, Map<String, dynamic>>{};

    // 1. Primary backend (CRM-managed leads; wins on id conflicts)
    try {
      final uri = Uri.parse('$_baseUrl/leads').replace(
        queryParameters: status != null ? {'status': status} : null,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] ?? data['leads']) as List<dynamic>?;
        if (list != null) {
          for (final e in list) {
            final lead = Map<String, dynamic>.from(e);
            final id = lead['id']?.toString();
            if (id != null && id.isNotEmpty) merged[id] = lead;
          }
          debugPrint('[BackendService] ✅ Fetched ${list.length} leads from primary backend');
        }
      }
    } catch (e) {
      debugPrint('[BackendService] Primary getLeads notice: $e.');
    }

    // 2. Leads written directly to Firebase RTDB by the Loan Calculator website.
    //    This guarantees website leads appear even when the app is talking to a
    //    backend that has not synced them yet.
    try {
      final res = await http
          .get(Uri.parse(_firebaseRtdbLeadsUrl))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          final now = DateTime.now().toUtc().toIso8601String();
          var added = 0;
          data.forEach((key, value) {
            if (value is! Map) return;
            final lead = Map<String, dynamic>.from(value);
            final id = (lead['id']?.toString().isNotEmpty == true)
                ? lead['id']!.toString()
                : key.toString();
            lead['id'] = id;
            if ((lead['name']?.toString().trim().isEmpty) ?? true) {
              lead['name'] = 'Unnamed Lead';
            }
            lead['status'] = _normalizeLeadStatus(lead['status']);
            if (lead['createdAt'] == null) lead['createdAt'] = now;
            if (lead['updatedAt'] == null) lead['updatedAt'] = lead['createdAt'];
            if (!merged.containsKey(id)) {
              merged[id] = lead;
              added++;
            }
          });
          debugPrint('[BackendService] 🔥 Merged $added Firebase RTDB lead(s) (total ${merged.length}).');
        }
      }
    } catch (e) {
      debugPrint('[BackendService] Firebase RTDB fetch note: $e');
    }

    // 3. Fallback: Loan-Calculator website database if the sources above failed
    if (merged.isEmpty) {
      final loanCalculatorEndpoints = [
        '$_loanCalculatorUrl/leads',
        'http://10.0.2.2:3000/api/leads', // Android emulator localhost alias
        'http://localhost:3000/api/leads',
        'http://127.0.0.1:3000/api/leads',
      ];

      for (final ep in loanCalculatorEndpoints) {
        try {
          final uri = Uri.parse(ep).replace(
            queryParameters: status != null ? {'status': status} : null,
          );
          final res = await http.get(uri).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final list = (data['leads'] ?? data['data']) as List<dynamic>?;
            if (list != null) {
              for (final e in list) {
                final lead = Map<String, dynamic>.from(e);
                final id = lead['id']?.toString();
                if (id != null && id.isNotEmpty) merged[id] = lead;
              }
              debugPrint('[BackendService] 🎯 Successfully fetched ${list.length} real leads from Loan Calculator database ($ep)');
              break;
            }
          }
        } catch (_) {
          // Continue to next endpoint candidate
        }
      }
    }

    var list = merged.values.toList()
      ..sort((a, b) {
        final at = DateTime.tryParse(a['createdAt']?.toString() ?? '');
        final bt = DateTime.tryParse(b['createdAt']?.toString() ?? '');
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        return (bt ?? epoch).compareTo(at ?? epoch);
      });

    if (status != null && status.isNotEmpty) {
      list = list.where((l) => l['status'] == status).toList();
    }

    return list;
  }

  /// Create a new lead manually in the CRM (with instant targeted or broadcast notifications)
  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    required String email,
    String source = 'Manual Entry',
    String campaign = 'Direct',
    String? ad,
    String status = 'newLead',
    String assignedTo = '',
    String note = '',
    String addedBy = 'Admin',
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[BackendService:createLead] Sending request: "$name" ($phone), assignedTo="${assignedTo.isEmpty ? "Unassigned (Broadcast)" : assignedTo}"');

      final res = await http
          .post(
            Uri.parse('$_baseUrl/leads'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'email': email,
              'source': source,
              'campaign': campaign,
              'ad': ad,
              'status': status,
              'assignedTo': assignedTo,
              'note': note,
              'addedBy': addedBy,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[BackendService:createLead] Status: ${res.statusCode}');
      debugPrint('[BackendService:createLead] Body: ${res.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : {'success': true, 'data': data};
    } catch (e) {
      debugPrint('❌ [BackendService:createLead] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Manually sync leads from Meta Form to Firebase
  Future<Map<String, dynamic>> syncMetaLeads({String? formId}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/leads/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'formId': formId ?? '102938475601'}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] syncMetaLeads error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Trigger Seed of all dummy data to Firebase Realtime Database
  Future<Map<String, dynamic>> seedDatabase() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/seed'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] seedDatabase error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ===================== TASKS =====================
  Future<List<Map<String, dynamic>>> getTasks({String filter = 'All'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/tasks').replace(
        queryParameters: filter != 'All' ? {'status': filter} : null,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getTasks error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> saveTask(Map<String, dynamic> task) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/tasks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(task),
          )
          .timeout(const Duration(seconds: 6));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/tasks/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ===================== TEAM =====================
  Future<List<Map<String, dynamic>>> getTeam() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/team'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getTeam error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> saveTeamMember(Map<String, dynamic> member) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/team'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(member),
          )
          .timeout(const Duration(seconds: 6));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> updateTeamMember(String id, Map<String, dynamic> updates) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/team/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTeamMember(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl/team/$id'))
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ===================== DYNAMIC META CONFIGURATION =====================
  /// Discover user profile, ad accounts, pages, and forms using a token
  Future<Map<String, dynamic>> discoverMetaAssets(String accessToken) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/meta/discover'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'accessToken': accessToken.trim()}),
          )
          .timeout(const Duration(seconds: 12));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] discoverMetaAssets error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Save dynamic Meta configuration to Firebase Realtime Database
  Future<Map<String, dynamic>> saveMetaConfig({
    required String accessToken,
    String? adAccountId,
    String? pageId,
    String? appSecret,
    String? pageName,
    String? adAccountName,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/meta/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'accessToken': accessToken.trim(),
              'adAccountId': adAccountId,
              'pageId': pageId,
              'appSecret': appSecret,
              'pageName': pageName,
              'adAccountName': adAccountName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] saveMetaConfig error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get active Meta configuration (masked)
  Future<Map<String, dynamic>> getMetaConfig() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/meta/config'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? {};
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaConfig error: $e');
      final alternate = _baseUrl.contains('localhost') || _baseUrl.contains('10.0.2.2')
          ? 'https://eligible-backend.onrender.com/api'
          : (kIsWeb || defaultTargetPlatform != TargetPlatform.android ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api');
      try {
        final altRes = await http
            .get(Uri.parse('$alternate/meta/config'))
            .timeout(const Duration(seconds: 8));
        if (altRes.statusCode == 200) {
          _baseUrl = alternate;
          final data = jsonDecode(altRes.body);
          return data['data'] ?? {};
        }
      } catch (_) {}
    }
    return {};
  }

  // ===================== NOTIFICATIONS (ADMIN & SALES) =====================

  /// Get notifications list from Firebase RTDB with unread count
  Future<Map<String, dynamic>> getNotifications({String? role, int limit = 50}) async {
    try {
      final qParams = <String, String>{'limit': limit.toString()};
      if (role != null) qParams['role'] = role;

      final uri = Uri.parse('$_baseUrl/notifications').replace(
        queryParameters: qParams,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('[BackendService] getNotifications error: $e');
    }
    return {'success': false, 'count': 0, 'unreadCount': 0, 'data': []};
  }

  /// Mark a notification as read
  Future<bool> markNotificationRead(String id) async {
    try {
      final res = await http
          .patch(Uri.parse('$_baseUrl/notifications/$id/read'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] markNotificationRead error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsRead({String? role}) async {
    try {
      final body = <String, dynamic>{};
      if (role != null) body['role'] = role;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/notifications/read-all'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] markAllNotificationsRead error: $e');
      return false;
    }
  }

  /// Trigger a test notification to verify setup for Admin & Sales Agents
  Future<Map<String, dynamic>> sendTestNotification({
    String? customTitle,
    String? customBody,
    String role = 'both',
  }) async {
    try {
      final body = <String, dynamic>{'role': role};
      if (customTitle != null) body['customTitle'] = customTitle;
      if (customBody != null) body['customBody'] = customBody;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/notifications/test'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] sendTestNotification error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Allot lead to a specific sales agent and trigger targeted multi-device notification
  Future<Map<String, dynamic>> allotLead(
    String leadId, {
    required String assignedTo,
    String allottedBy = 'Admin',
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[BackendService:allotLead] Alloting lead $leadId -> assignedTo: "$assignedTo" by "$allottedBy"');

      final res = await http
          .post(
            Uri.parse('$_baseUrl/leads/$leadId/allot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'assignedTo': assignedTo,
              'allottedBy': allottedBy,
            }),
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('[BackendService:allotLead] Status: ${res.statusCode}');
      debugPrint('[BackendService:allotLead] Body: ${res.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('❌ [BackendService:allotLead] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Register an FCM device token for push notifications (multi-device login support)
  Future<Map<String, dynamic>> registerFcmToken({
    required String userId,
    required String token,
    String role = 'sales_agent',
    String name = 'App User',
    String deviceName = 'Mobile App',
    String platform = 'android',
  }) async {
    try {
      debugPrint('[BackendService:registerFcmToken] Registering token for $name (ID: $userId, Role: $role, Device: $deviceName)...');

      final res = await http
          .post(
            Uri.parse('$_baseUrl/notifications/register-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'token': token,
              'role': role,
              'name': name,
              'deviceName': deviceName,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 6));

      debugPrint('[BackendService:registerFcmToken] Status: ${res.statusCode} | Response: ${res.body}');
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('❌ [BackendService:registerFcmToken] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch live notification dispatch logs
  Future<List<Map<String, dynamic>>> getNotificationLogs({int limit = 50}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/notifications/logs?limit=$limit'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('❌ [BackendService:getNotificationLogs] Error: $e');
    }
    return [];
  }
}
