import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eligible_project/models/user.dart';
import 'package:eligible_project/services/auth_service.dart';
import 'package:eligible_project/screens/create_meta_campaign_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.loginAs(UserModel.admin);
  });

  group('Meta Campaign Draft and Billing Tests', () {
    testWidgets('Screen renders properly with admin access', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateMetaCampaignScreen(),
          ),
        ),
      );
      await tester.pump();

      // Check for Draft indicator in AppBar
      expect(find.text('Draft'), findsOneWidget);

      // Verify the campaign name field text
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.any((tf) => tf.controller?.text.contains('Pune') == true), isTrue);
    });

    testWidgets('Draft prompt does NOT show if no draft exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateMetaCampaignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume Saved Campaign?'), findsNothing);
    });

    testWidgets('Draft prompt appears when draft is found and resumes correctly', (WidgetTester tester) async {
      final savedDraft = {
        'campaignName': 'Auto Saved Diwali Loan Promo',
        'budget': '500',
        'savedAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
        'targetedPincodes': ['411038', '411014'],
        'targetedAreas': ['Kothrud', 'Baner'],
        'headline': 'Low EMI Quick Sanction',
      };

      SharedPreferences.setMockInitialValues({
        'meta_campaign_draft_v1': jsonEncode(savedDraft),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateMetaCampaignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the prompt dialog appeared
      expect(find.text('Resume Saved Campaign?'), findsOneWidget);
      expect(find.textContaining('Auto Saved Diwali Loan Promo'), findsOneWidget);
      expect(find.text('Use Saved Draft'), findsOneWidget);
      expect(find.text('Create New Campaign'), findsOneWidget);

      // Tap "Use Saved Draft"
      await tester.tap(find.text('Use Saved Draft'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Resume Saved Campaign?'), findsNothing);

      // Form field should reflect the resumed draft
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.any((tf) => tf.controller?.text == 'Auto Saved Diwali Loan Promo'), isTrue);
      expect(textFields.any((tf) => tf.controller?.text == '500'), isTrue);
    });

    testWidgets('Draft prompt clears draft when "Create New Campaign" is chosen', (WidgetTester tester) async {
      final savedDraft = {
        'campaignName': 'Old Discarded Campaign',
        'budget': '2000',
        'savedAt': DateTime.now().toIso8601String(),
      };

      SharedPreferences.setMockInitialValues({
        'meta_campaign_draft_v1': jsonEncode(savedDraft),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateMetaCampaignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume Saved Campaign?'), findsOneWidget);

      // Tap "Create New Campaign"
      await tester.tap(find.text('Create New Campaign'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Resume Saved Campaign?'), findsNothing);

      // SharedPreferences draft should be cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('meta_campaign_draft_v1'), isNull);

      // Default campaign name should be present instead
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.any((tf) => tf.controller?.text.contains('Pune') == true), isTrue);
    });

    testWidgets('Navigating to Step 4 automatically saves draft in SharedPreferences', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreateMetaCampaignScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      expect(find.text('Continue to Step 2'), findsOneWidget);
      await tester.tap(find.text('Continue to Step 2'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      expect(find.text('Continue to Step 3'), findsOneWidget);
      await tester.tap(find.text('Continue to Step 3'));
      await tester.pumpAndSettle();

      // Step 3 -> Step 4 (Review & Publish)
      expect(find.text('Continue to Step 4'), findsOneWidget);
      await tester.tap(find.text('Continue to Step 4'));
      await tester.pumpAndSettle();

      // Verify Step 4 shows the Draft Automatically Saved banner
      expect(find.text('Draft Automatically Saved'), findsOneWidget);
      expect(find.text('Draft Saved'), findsOneWidget);

      // Verify SharedPreferences has the draft key saved
      final prefs = await SharedPreferences.getInstance();
      final draftRaw = prefs.getString('meta_campaign_draft_v1');
      expect(draftRaw, isNotNull);

      final draftData = jsonDecode(draftRaw!) as Map<String, dynamic>;
      expect(draftData['campaignName'], contains('Pune'));
      expect(draftData['savedAt'], isNotNull);
    });
  });
}
