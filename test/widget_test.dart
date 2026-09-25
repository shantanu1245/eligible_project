import 'package:flutter_test/flutter_test.dart';
import 'package:eligible_project/main.dart';

void main() {
  testWidgets('LeadFlow CRM loads', (WidgetTester tester) async {
    await tester.pumpWidget(const LeadFlowCRM());

    expect(find.text('LeadFlow CRM'), findsOneWidget);
  });
}