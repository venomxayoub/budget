import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:budget_manager/main.dart';
import 'package:budget_manager/providers/transaction_provider.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const BudgetManagerApp(),
      ),
    );

    expect(find.text('No entries yet'), findsOneWidget);
  });
}
