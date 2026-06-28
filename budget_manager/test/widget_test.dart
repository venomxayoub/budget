import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget_manager/main.dart';
import 'package:budget_manager/models/expense_category.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:budget_manager/screens/category_form_screen.dart';
import 'package:budget_manager/screens/entry_form_screen.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const BudgetManagerApp(),
      ),
    );

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('drawer opens from a left-edge swipe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const BudgetManagerApp(),
      ),
    );

    await tester.dragFrom(const Offset(1, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('entry edit form is prefilled', (WidgetTester tester) async {
    final entry = EntryItem(
      id: 7,
      isExpense: true,
      amountCents: 1234,
      note: 'Existing note',
      categoryIds: const [1],
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: MaterialApp(
          home: EntryFormScreen(isExpense: true, entry: entry),
        ),
      ),
    );

    expect(find.text('12.34'), findsOneWidget);
    expect(find.text('Existing note'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('category edit form is prefilled', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: MaterialApp(
          home: CategoryFormScreen(
            isExpense: true,
            expenseCategory: ExpenseCategory(
              id: 3,
              name: 'Groceries',
              emoji: '🥦',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('🥦'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
