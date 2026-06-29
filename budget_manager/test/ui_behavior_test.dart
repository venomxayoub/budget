import 'package:budget_manager/main.dart';
import 'package:budget_manager/models/debt_transaction.dart';
import 'package:budget_manager/models/expense.dart';
import 'package:budget_manager/models/income.dart';
import 'package:budget_manager/models/income_category.dart';
import 'package:budget_manager/screens/archived_debt_profiles_screen.dart';
import 'package:budget_manager/screens/category_form_screen.dart';
import 'package:budget_manager/screens/debt_profile_detail_screen.dart';
import 'package:budget_manager/screens/debt_profile_form_screen.dart';
import 'package:budget_manager/screens/debt_transaction_detail_screen.dart';
import 'package:budget_manager/screens/debt_transaction_form_screen.dart';
import 'package:budget_manager/screens/entry_detail_screen.dart';
import 'package:budget_manager/screens/entry_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_fixture.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('expense form validates input and creates the intended entry', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpScreen(tester, fixture, EntryFormScreen(isExpense: true));

    await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
    await tester.pump();
    expect(find.text('Please enter a price'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '12.34');
    await tester.enterText(find.byType(TextField).at(1), 'Lunch');
    await tester.tap(find.text('Food'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
    await _settleAsync(tester);

    final entry = fixture.provider.entries.single;
    expect(entry.isExpense, isTrue);
    expect(entry.amountCents, 1234);
    expect(entry.note, 'Lunch');
    expect(
      fixture.provider.getExpenseCategoryById(entry.categoryIds.single)?.name,
      'Food',
    );
    expect(find.byType(EntryFormScreen), findsOneWidget);
    expect(find.text('12.34'), findsNothing);
    expect(find.text('Lunch'), findsNothing);
  });

  testWidgets('entry form rejects zero and malformed prices', (tester) async {
    final fixture = await _createFixture(tester);
    await _pumpScreen(tester, fixture, EntryFormScreen(isExpense: false));

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Income'));
    await tester.pump();
    expect(find.text('Please enter a valid price'), findsOneWidget);
    expect(fixture.provider.entries, isEmpty);
  });

  testWidgets('income form creates an income with its selected category', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpScreen(tester, fixture, EntryFormScreen(isExpense: false));

    await tester.enterText(find.byType(TextField).at(0), '80.25');
    await tester.enterText(find.byType(TextField).at(1), 'Freelance invoice');
    await tester.tap(find.text('Freelance'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add Income'));
    await _settleAsync(tester);

    final entry = fixture.provider.entries.single;
    expect(entry.isExpense, isFalse);
    expect(entry.amountCents, 8025);
    expect(entry.note, 'Freelance invoice');
    expect(
      fixture.provider.getIncomeCategoryById(entry.categoryIds.single)?.name,
      'Freelance',
    );
  });

  testWidgets('editing an entry updates it instead of creating a duplicate', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    final categoryId = fixture.provider.expenseCategories.first.id!;
    final createdAt = DateTime(2026, 1, 1, 10);
    await tester.runAsync(
      () => fixture.provider.addExpense(
        Expense(
          categoryIds: [categoryId],
          amountCents: 100,
          note: 'Before',
          createdAt: createdAt,
        ),
      ),
    );
    final entry = fixture.provider.entries.single;
    await _pumpScreen(
      tester,
      fixture,
      EntryFormScreen(isExpense: true, entry: entry),
    );

    await tester.enterText(find.byType(TextField).at(0), '2.50');
    await tester.enterText(find.byType(TextField).at(1), 'After');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await _settleAsync(tester);

    expect(fixture.provider.entries, hasLength(1));
    expect(fixture.provider.entries.single.id, entry.id);
    expect(fixture.provider.entries.single.createdAt, createdAt);
    expect(fixture.provider.entries.single.amountCents, 250);
    expect(fixture.provider.entries.single.note, 'After');
  });

  testWidgets('category form requires name and emoji before saving', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpScreen(
      tester,
      fixture,
      const CategoryFormScreen(isExpense: true),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('Please enter a name'), findsOneWidget);

    await _pumpScreen(
      tester,
      fixture,
      const CategoryFormScreen(isExpense: true),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Pets');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('Please enter an emoji'), findsOneWidget);

    await _pumpScreen(
      tester,
      fixture,
      const CategoryFormScreen(isExpense: true),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Pets');
    await tester.enterText(find.byType(TextField).at(1), '🐾');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await _settleAsync(tester);
    expect(
      fixture.provider.expenseCategories.map((category) => category.name),
      contains('Pets'),
    );
    expect(
      fixture.provider.incomeCategories.map((category) => category.name),
      isNot(contains('Pets')),
    );
  });

  testWidgets('income category editing preserves identity and type', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    final category = fixture.provider.incomeCategories.singleWhere(
      (item) => item.name == 'Gift',
    );
    await _pumpScreen(
      tester,
      fixture,
      CategoryFormScreen(
        isExpense: false,
        incomeCategory: IncomeCategory(
          id: category.id,
          name: category.name,
          emoji: category.emoji,
          createdAt: category.createdAt,
          updatedAt: category.updatedAt,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Family gift');
    await tester.enterText(find.byType(TextField).at(1), '🎁');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await _settleAsync(tester);

    expect(
      fixture.provider.getIncomeCategoryById(category.id!)?.name,
      'Family gift',
    );
    expect(
      fixture.provider.expenseCategories.map((item) => item.name),
      isNot(contains('Family gift')),
    );
  });

  testWidgets('deleting an entry archives immediately without confirmation', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(
      () => fixture.provider.addExpense(
        Expense(
          categoryIds: [fixture.provider.expenseCategories.first.id!],
          amountCents: 650,
          note: 'Archive me',
        ),
      ),
    );
    final entry = fixture.provider.entries.single;
    await _pumpScreen(tester, fixture, EntryDetailScreen(entry: entry));

    await tester.tap(find.text('Delete'));
    await _settleAsync(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.provider.entries, isEmpty);
    expect(fixture.provider.archivedEntries.single.id, entry.id);
  });

  testWidgets('archived entry can be restored or permanently deleted', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(
      () => fixture.provider.addExpense(
        Expense(
          categoryIds: [fixture.provider.expenseCategories.first.id!],
          amountCents: 900,
          note: 'Archived',
        ),
      ),
    );
    final id = fixture.provider.entries.single.id;
    await tester.runAsync(() => fixture.provider.deleteExpense(id));
    var archived = fixture.provider.archivedEntries.single;
    await _pumpScreen(tester, fixture, EntryDetailScreen(entry: archived));

    await tester.tap(find.text('Restore'));
    await _settleAsync(tester);
    expect(fixture.provider.entries.single.id, id);

    await tester.runAsync(() => fixture.provider.deleteExpense(id));
    archived = fixture.provider.archivedEntries.single;
    await _pumpScreen(tester, fixture, EntryDetailScreen(entry: archived));
    await tester.tap(find.text('Delete Forever'));
    await _settleAsync(tester);
    expect(fixture.provider.entries, isEmpty);
    expect(fixture.provider.archivedEntries, isEmpty);
  });

  testWidgets('debt profile form validates and accepts a signed balance', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpScreen(tester, fixture, const DebtProfileFormScreen());

    await tester.tap(find.byKey(const Key('save-debt-profile')));
    await tester.pump();
    expect(find.text('Name is required'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('debt-profile-name')), 'Sam');
    await tester.enterText(
      find.byKey(const Key('debt-initial-balance')),
      '-12.50',
    );
    await tester.tap(find.byKey(const Key('save-debt-profile')));
    await _settleAsync(tester);
    expect(fixture.provider.debtProfiles.single.name, 'Sam');
    expect(
      fixture.provider.debtBalanceForProfile(
        fixture.provider.debtProfiles.single.id!,
      ),
      -1250,
    );
  });

  testWidgets('debt transaction form enforces type-specific amounts', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(
      () => fixture.provider.createDebtProfile(
        name: 'Ledger',
        initialBalanceCents: 1000,
      ),
    );
    final id = fixture.provider.debtProfiles.single.id!;
    await _pumpScreen(
      tester,
      fixture,
      DebtTransactionFormScreen(profileId: id, type: DebtTransactionType.gave),
    );

    await tester.enterText(
      find.byKey(const Key('debt-transaction-amount')),
      '0',
    );
    await tester.tap(find.byKey(const Key('save-debt-transaction')));
    await tester.pump();
    expect(find.text('Amount must be positive'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('debt-transaction-amount')),
      '5.25',
    );
    await tester.enterText(
      find.byKey(const Key('debt-transaction-note')),
      'Additional loan',
    );
    await tester.tap(find.byKey(const Key('save-debt-transaction')));
    await _settleAsync(tester);
    expect(fixture.provider.debtBalanceForProfile(id), 1525);
    expect(
      fixture.provider.debtTransactionsForProfile(id).single.note,
      'Additional loan',
    );

    await _pumpScreen(
      tester,
      fixture,
      DebtTransactionFormScreen(
        profileId: id,
        type: DebtTransactionType.update,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('debt-transaction-amount')),
      '-2.00',
    );
    await tester.tap(find.byKey(const Key('save-debt-transaction')));
    await _settleAsync(tester);
    expect(fixture.provider.debtBalanceForProfile(id), -200);
  });

  testWidgets('confirmed debt transaction deletion changes the balance', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(
      () => fixture.provider.createDebtProfile(
        name: 'Ledger',
        initialBalanceCents: 1000,
      ),
    );
    final profileId = fixture.provider.debtProfiles.single.id!;
    await tester.runAsync(
      () => fixture.provider.addDebtTransaction(
        profileId: profileId,
        type: DebtTransactionType.received,
        amountCents: 250,
      ),
    );
    final transactionId =
        fixture.provider.debtTransactionsForProfile(profileId).single.id!;
    await _pumpScreen(
      tester,
      fixture,
      DebtTransactionDetailScreen(transactionId: transactionId),
    );

    await tester.tap(find.byKey(const Key('delete-debt-transaction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-debt-transaction')));
    await _settleAsync(tester);
    expect(fixture.provider.debtTransactionsForProfile(profileId), isEmpty);
    expect(fixture.provider.debtBalanceForProfile(profileId), 1000);
  });

  testWidgets('debt profile can be archived and restored with history', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(
      () => fixture.provider.createDebtProfile(
        name: 'Archive me',
        initialBalanceCents: 300,
      ),
    );
    final id = fixture.provider.debtProfiles.single.id!;
    await tester.runAsync(
      () => fixture.provider.addDebtTransaction(
        profileId: id,
        type: DebtTransactionType.gave,
        amountCents: 200,
        note: 'Preserved',
      ),
    );
    await _pumpScreen(tester, fixture, DebtProfileDetailScreen(profileId: id));

    await tester.tap(find.byKey(const Key('delete-debt-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-debt-profile')));
    await _settleAsync(tester);
    expect(fixture.provider.debtProfiles, isEmpty);
    expect(fixture.provider.archivedDebtProfiles.single.id, id);

    await _pumpScreen(
      tester,
      fixture,
      const Scaffold(body: ArchivedDebtProfilesScreen()),
    );
    await tester.tap(find.byKey(Key('restore-debt-profile-$id')));
    await _settleAsync(tester);
    expect(fixture.provider.debtProfiles.single.id, id);
    expect(fixture.provider.debtProfiles.single.name, 'Archive me');
    expect(
      fixture.provider.debtTransactionsForProfile(id).single.note,
      'Preserved',
    );
  });

  testWidgets('home shows current-month income and expense totals', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    final now = DateTime.now();
    await tester.runAsync(
      () => fixture.provider.addExpense(
        Expense(
          categoryIds: [fixture.provider.expenseCategories.first.id!],
          amountCents: 1200,
          note: 'Current expense',
          createdAt: now,
        ),
      ),
    );
    await tester.runAsync(
      () => fixture.provider.addIncome(
        budgetIncome(
          categoryId: fixture.provider.incomeCategories.first.id!,
          amountCents: 2000,
          note: 'Current income',
          createdAt: now,
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.provider,
        child: const BudgetManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget);
    expect(find.text(r'+$20.00'), findsWidgets);
    expect(find.text(r'-$12.00'), findsWidgets);
    expect(find.text('Current expense'), findsOneWidget);
    expect(find.text('Current income'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final previousMonth = DateTime(now.year, now.month - 1);
    expect(
      find.text(
        'No entries in ${DateFormat('MMMM yyyy').format(previousMonth)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a home entry opens its complete detail view', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    final category = fixture.provider.expenseCategories.singleWhere(
      (item) => item.name == 'Food',
    );
    await tester.runAsync(
      () => fixture.provider.addExpense(
        Expense(
          categoryIds: [category.id!],
          amountCents: 1875,
          note: 'Dinner',
          createdAt: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.provider,
        child: const BudgetManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text(r'-$18.75'), findsOneWidget);
    expect(find.text('🍕  Food'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('drawer navigation exposes every user data area', (tester) async {
    final fixture = await _createFixture(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.provider,
        child: const BudgetManagerApp(),
      ),
    );
    await tester.dragFrom(const Offset(64, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Debts & Loans'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Import Previous Data'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });
}

Future<TestFixture> _createFixture(WidgetTester tester) async {
  final fixture = (await tester.runAsync(TestFixture.create))!;
  addTearDown(fixture.dispose);
  return fixture;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  TestFixture fixture,
  Widget screen,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: fixture.provider,
      child: MaterialApp(home: screen),
    ),
  );
}

Future<void> _settleAsync(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Income budgetIncome({
  required int categoryId,
  required int amountCents,
  required String note,
  required DateTime createdAt,
}) => Income(
  categoryIds: [categoryId],
  amountCents: amountCents,
  note: note,
  createdAt: createdAt,
);
