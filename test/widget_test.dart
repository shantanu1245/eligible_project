import 'package:flutter_test/flutter_test.dart';
import 'package:eligible_project/main.dart';

void main() {
  testWidgets('Eligible CRM loads', (WidgetTester tester) async {
    await tester.pumpWidget(const EligibleCRMApp());

    expect(find.text('Eligible CRM'), findsWidgets);
  });
}