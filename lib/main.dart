import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const LeadFlowCRM());
}

class LeadFlowCRM extends StatelessWidget {
  const LeadFlowCRM({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeadFlow CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
