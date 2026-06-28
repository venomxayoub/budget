import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget_manager/main.dart';
import 'package:budget_manager/models/expense_category.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:budget_manager/screens/category_form_screen.dart';
import 'package:budget_manager/screens/entry_form_screen.dart';
import 'package:budget_manager/models/debt_transaction.dart';
import 'package:budget_manager/screens/debt_profile_detail_screen.dart';
import 'package:budget_manager/screens/debt_transaction_detail_screen.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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
    expect(find.text('Debts & Loans'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsNWidgets(2));
    expect(find.text('Debt Profiles'), findsOneWidget);

    await tester.tap(find.text('Debt Profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Archived Debt Profiles'), findsOneWidget);
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

  testWidgets(
    'profile deletion requires confirmation and cancel preserves it',
    (WidgetTester tester) async {
      final fixture = (await tester.runAsync(_createDebtFixture))!;
      addTearDown(fixture.dispose);
      await tester.runAsync(
        () => fixture.provider.createDebtProfile(
          name: 'Dialog profile',
          initialBalanceCents: 0,
        ),
      );
      final profileId = fixture.provider.debtProfiles.single.id!;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: fixture.provider,
          child: MaterialApp(
            home: DebtProfileDetailScreen(profileId: profileId),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('delete-debt-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Profile?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-delete-debt-profile')));
      await tester.pumpAndSettle();
      expect(fixture.provider.debtProfiles, hasLength(1));
    },
  );

  testWidgets(
    'transaction deletion requires confirmation and cancel preserves effect',
    (WidgetTester tester) async {
      final fixture = (await tester.runAsync(_createDebtFixture))!;
      addTearDown(fixture.dispose);
      await tester.runAsync(
        () => fixture.provider.createDebtProfile(
          name: 'Transaction dialog',
          initialBalanceCents: 100,
        ),
      );
      final profileId = fixture.provider.debtProfiles.single.id!;
      await tester.runAsync(
        () => fixture.provider.addDebtTransaction(
          profileId: profileId,
          type: DebtTransactionType.gave,
          amountCents: 200,
        ),
      );
      final transactionId =
          fixture.provider.debtTransactionsForProfile(profileId).single.id!;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: fixture.provider,
          child: MaterialApp(
            home: DebtTransactionDetailScreen(transactionId: transactionId),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('delete-debt-transaction')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Transaction?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-delete-debt-transaction')));
      await tester.pumpAndSettle();
      expect(fixture.provider.debtBalanceForProfile(profileId), 300);
    },
  );
}

Future<_DebtFixture> _createDebtFixture() async {
  final directory = await Directory.systemTemp.createTemp(
    'budget_debt_widget_test_',
  );
  final databaseHelper = DatabaseHelper.forTesting(
    databaseFactory: databaseFactoryFfi,
    path: path.join(directory.path, 'budget.db'),
  );
  final provider = TransactionProvider(databaseHelper: databaseHelper);
  await provider.loadData();
  return _DebtFixture(directory, databaseHelper, provider);
}

class _DebtFixture {
  final Directory directory;
  final DatabaseHelper databaseHelper;
  final TransactionProvider provider;

  const _DebtFixture(this.directory, this.databaseHelper, this.provider);

  Future<void> dispose() async {
    await databaseHelper.close();
    await directory.delete(recursive: true);
  }
}
