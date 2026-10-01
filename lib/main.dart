import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/backend_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start live server pinger to prevent Render free instance from sleeping
  BackendService().startKeepAlivePinger(interval: const Duration(minutes: 5));

  runApp(const EligibleCRMApp());
}

class EligibleCRMApp extends StatelessWidget {
  const EligibleCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eligible CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
