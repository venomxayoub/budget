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
import 'package:budget_manager/models/subscription.dart';
import 'package:budget_manager/screens/subscription_detail_screen.dart';
import 'package:budget_manager/screens/subscription_form_screen.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TransactionProvider> loadedProvider() async {
    final dir = await Directory.systemTemp.createTemp('budget_widget_test_');
    final db = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      path: path.join(dir.path, 'budget.db'),
    );
    final p = TransactionProvider(databaseHelper: db);
    await p.loadData();
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    return p;
  }

  testWidgets('App loads home screen', (WidgetTester tester) async {
    final provider = await tester.runAsync(() => loadedProvider());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const BudgetManagerApp(),
      ),
    );

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('drawer opens from a left-to-right swipe started inward', (
    WidgetTester tester,
  ) async {
    final provider = await tester.runAsync(() => loadedProvider());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const BudgetManagerApp(),
      ),
    );

    await tester.dragFrom(const Offset(64, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Debts & Loans'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsNWidgets(2));
    expect(find.text('Debt Profiles'), findsOneWidget);

    await tester.tap(find.text('Debt Profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Archived Debt Profiles'), findsOneWidget);
  });

  testWidgets('drawer keeps data controls above bottom navigation links', (
    WidgetTester tester,
  ) async {
    final provider = await tester.runAsync(() => loadedProvider());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const BudgetManagerApp(),
      ),
    );

    await tester.dragFrom(const Offset(64, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    final importBottom = tester.getBottomLeft(
      find.text('Import Previous Data'),
    ).dy;
    final updateBottom = tester.getBottomLeft(find.text('Update')).dy;

    for (final label in [
      'Entries',
      'Subscriptions',
      'Categories',
      'Debts & Loans',
      'Archive',
    ]) {
      expect(tester.getTopLeft(find.text(label)).dy, greaterThan(importBottom));
      expect(tester.getTopLeft(find.text(label)).dy, greaterThan(updateBottom));
    }
  });

  testWidgets('drawer opens the subscriptions view and New form', (
    WidgetTester tester,
  ) async {
    final provider = await tester.runAsync(() => loadedProvider());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const BudgetManagerApp(),
      ),
    );

    await tester.dragFrom(const Offset(64, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();

    expect(find.text('No subscriptions yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-subscription')));
    await tester.pumpAndSettle();
    expect(find.text('New Subscription'), findsOneWidget);
    expect(find.byKey(const Key('subscription-name')), findsOneWidget);
    expect(find.byKey(const Key('subscription-price')), findsOneWidget);
    expect(find.byKey(const Key('subscription-period')), findsOneWidget);
    expect(find.byKey(const Key('subscription-renewal-date')), findsOneWidget);
  });

  testWidgets('subscription edit form is prefilled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: MaterialApp(
          home: SubscriptionFormScreen(
            subscription: Subscription(
              id: 4,
              name: 'Music',
              priceCents: 999,
              period: SubscriptionPeriod.annual,
              status: SubscriptionStatus.active,
              renewalAnchorDate: DateTime(2026, 8, 20),
              nextRenewalDate: DateTime(2026, 8, 20),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('9.99'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('subscription detail status and payment deletion are shared', (
    WidgetTester tester,
  ) async {
    final fixture = (await tester.runAsync(_createDebtFixture))!;
    addTearDown(fixture.dispose);
    await tester.runAsync(
      () => fixture.provider.createSubscription(
        name: 'Video',
        priceCents: 1499,
        period: SubscriptionPeriod.monthly,
        firstRenewalDate: DateTime.now().add(const Duration(days: 10)),
      ),
    );
    final subscriptionId = fixture.provider.subscriptions.single.id!;
    final paymentId =
        fixture.provider.subscriptionPayments(subscriptionId).single.id!;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.provider,
        child: MaterialApp(
          home: SubscriptionDetailScreen(subscriptionId: subscriptionId),
        ),
      ),
    );

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.byKey(const Key('pause-subscription')), findsOneWidget);
    expect(find.byKey(const Key('cancel-subscription')), findsOneWidget);

    await tester.tap(find.byKey(Key('delete-subscription-payment-$paymentId')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Payment?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(fixture.provider.entries, isEmpty);
    expect(fixture.provider.subscriptionPayments(subscriptionId), isEmpty);
    expect(find.text('Payment'), findsNothing);
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
