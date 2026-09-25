class AuthService {
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    // Temporary frontend authentication.
    //
    // Later this method can call:
    // - Firebase Authentication
    // - Your own secure backend API
    // - OAuth
    //
    // Never store real passwords in the Flutter application.

    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    return email.trim().isNotEmpty && password.length >= 6;
  }

  Future<void> logout() async {
    // Future backend/session logout can be added here.
  }
}