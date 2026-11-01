import 'package:flutter/material.dart';
import 'models/user.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve saved user session to keep user logged in across restarts
  UserModel? savedUser;
  try {
    savedUser = await AuthService.instance.getSavedUserSession();
  } catch (e) {
    debugPrint('⚠️ Error retrieving saved user session: $e');
  }

  // Mount root app with initial user if authenticated, otherwise LoginScreen
  runApp(EligibleCRMApp(initialUser: savedUser));

  // Initialize background services right after the first frame has rendered smoothly
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushNotificationService.instance.initialize();
    BackendService().startKeepAlivePinger(interval: const Duration(minutes: 5));
  });
}

class EligibleCRMApp extends StatelessWidget {
  final UserModel? initialUser;

  const EligibleCRMApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eligible CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialUser != null
          ? DashboardScreen(user: initialUser!)
          : const LoginScreen(),
    );
  }
}
