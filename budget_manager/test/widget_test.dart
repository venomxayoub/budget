import 'package:flutter_test/flutter_test.dart';
import 'package:budget_manager/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetManagerApp());
    expect(find.text('Budget Manager'), findsOneWidget);
  });
}
