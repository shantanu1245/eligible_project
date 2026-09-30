import '../models/user.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  UserModel? _currentUser = UserModel.admin;

  UserModel? get currentUser => _currentUser;

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

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

    return _currentUser;
  }

  void loginAs(UserModel user) {
    _currentUser = user;
  }

  Future<void> logout() async {
    _currentUser = null;
  }
}