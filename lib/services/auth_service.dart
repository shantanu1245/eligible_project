import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../screens/login_screen.dart';
import 'backend_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  static const String _userSessionKey = 'logged_in_user_session';
  static const String _isLoggedInKey = 'is_user_logged_in';

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  /// Retrieve the persistently saved user session from local storage.
  /// Returns null if the user has logged out or never logged in.
  Future<UserModel?> getSavedUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final userJsonStr = prefs.getString(_userSessionKey);

      if (isLoggedIn && userJsonStr != null && userJsonStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        final user = UserModel.fromJson(userMap);
        final cleanEmail = user.email.trim().toLowerCase();
        // Accept Admin or any valid agent/executive
        if (cleanEmail == 'admin@theligible.in' ||
            user.isSalesExecutive ||
            user.role == UserRole.salesExecutive) {
          _currentUser = user;
          debugPrint('🔐 [AuthService] Restored active session for: ${_currentUser?.name} (${_currentUser?.email})');
          return _currentUser;
        } else {
          // Clear legacy demo session so user logs in with new credentials
          await logout();
          return null;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AuthService] Error restoring user session: $e');
    }
    return null;
  }

  /// Save user session persistently so user remains logged in across app restarts.
  Future<void> saveUserSession(UserModel user) async {
    try {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
      debugPrint('💾 [AuthService] Saved persistent session for: ${user.name} (${user.email})');
    } catch (e) {
      debugPrint('⚠️ [AuthService] Error saving user session: $e');
    }
  }

  /// Authenticate with email/password and persist session.
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // 1. Authenticate Admin credentials
    if (cleanEmail == 'admin@theligible.in' && cleanPassword == 'eligible@098') {
      _currentUser = UserModel.admin;
      await saveUserSession(_currentUser!);
      return _currentUser;
    }

    // 2. Authenticate Team Member / Agent via backend
    try {
      final backendUser = await BackendService().loginTeamMember(
        email: cleanEmail,
        password: cleanPassword,
      );

      if (backendUser != null) {
        final roleStr = backendUser['role']?.toString().toLowerCase() ?? '';
        final role = (roleStr.contains('admin'))
            ? UserRole.administrator
            : UserRole.salesExecutive;

        _currentUser = UserModel(
          id: backendUser['id']?.toString() ?? 'U-${DateTime.now().millisecondsSinceEpoch}',
          name: backendUser['name']?.toString() ?? 'Sales Agent',
          email: backendUser['email']?.toString() ?? cleanEmail,
          role: role,
          initial: backendUser['initial']?.toString() ??
              (backendUser['name'] != null && backendUser['name'].toString().isNotEmpty
                  ? backendUser['name'].toString().substring(0, 1).toUpperCase()
                  : 'A'),
        );

        await saveUserSession(_currentUser!);
        return _currentUser;
      }

      // 3. Fallback: check getTeam directly in case backend is offline or locally cached
      final team = await BackendService().getTeam();
      final match = team.firstWhere(
        (m) =>
            m['email']?.toString().trim().toLowerCase() == cleanEmail &&
            m['password']?.toString().trim() == cleanPassword,
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        final roleStr = match['role']?.toString().toLowerCase() ?? '';
        final role = (roleStr.contains('admin'))
            ? UserRole.administrator
            : UserRole.salesExecutive;

        _currentUser = UserModel(
          id: match['id']?.toString() ?? 'U-${DateTime.now().millisecondsSinceEpoch}',
          name: match['name']?.toString() ?? 'Sales Agent',
          email: match['email']?.toString() ?? cleanEmail,
          role: role,
          initial: match['initial']?.toString() ??
              (match['name'] != null && match['name'].toString().isNotEmpty
                  ? match['name'].toString().substring(0, 1).toUpperCase()
                  : 'A'),
        );

        await saveUserSession(_currentUser!);
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[AuthService] Agent login check error: $e');
    }

    return null;
  }

  /// Direct login as a selected user and persist session.
  Future<void> loginAs(UserModel user) async {
    _currentUser = user;
    await saveUserSession(user);
  }

  /// Completely clear user session and navigate back to LoginScreen.
  Future<void> logout([BuildContext? context]) async {
    final prevUser = _currentUser?.name;
    _currentUser = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userSessionKey);
      await prefs.setBool(_isLoggedInKey, false);
      debugPrint('👋 [AuthService] User "$prevUser" logged out. Session cleared.');
    } catch (e) {
      debugPrint('⚠️ [AuthService] Error clearing user session: $e');
    }

    if (context != null && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
