import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_app/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyFinanceApp());
    expect(find.text('家庭记账'), findsOneWidget);
  });
}
