import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../screens/login_screen.dart';

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
        _currentUser = UserModel.fromJson(userMap);
        debugPrint('🔐 [AuthService] Restored active session for: ${_currentUser?.name} (${_currentUser?.roleDisplayName})');
        return _currentUser;
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
    await Future.delayed(const Duration(milliseconds: 400));

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.length < 4) {
      return null;
    }

    if (cleanEmail.contains('amit')) {
      _currentUser = UserModel.executiveAmit;
    } else if (cleanEmail.contains('priya')) {
      _currentUser = UserModel.executivePriya;
    } else {
      // Default to Administrator
      _currentUser = UserModel.admin;
    }

    if (_currentUser != null) {
      await saveUserSession(_currentUser!);
    }

    return _currentUser;
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
