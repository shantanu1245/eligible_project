import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  /// Default Base URL pointing to deployed Render cloud backend
  String _baseUrl = 'https://eligible-backend.onrender.com/api';

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
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

  /// Fetch leads from backend
  Future<List<Map<String, dynamic>>> getLeads({String? status}) async {
    try {
      final uri = Uri.parse('$_baseUrl/leads').replace(
        queryParameters: status != null ? {'status': status} : null,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BackendService] getLeads error: $e');
    }
    return [];
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
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? {};
      }
    } catch (e) {
      debugPrint('[BackendService] getMetaConfig error: $e');
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
      final res = await http
          .post(
            Uri.parse('$_baseUrl/leads/$leadId/allot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'assignedTo': assignedTo,
              'allottedBy': allottedBy,
            }),
          )
          .timeout(const Duration(seconds: 6));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] allotLead error: $e');
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
          .timeout(const Duration(seconds: 5));
      return jsonDecode(res.body);
    } catch (e) {
      debugPrint('[BackendService] registerFcmToken error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
