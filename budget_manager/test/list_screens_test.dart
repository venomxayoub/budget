import 'package:budget_manager/models/subscription.dart';
import 'package:budget_manager/screens/categories_screen.dart';
import 'package:budget_manager/screens/debt_profiles_screen.dart';
import 'package:budget_manager/screens/subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_fixture.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('categories list renders both category sets and edit callbacks', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    Object? edited;

    await _pumpScreen(
      tester,
      fixture,
      CategoriesScreen(
        onEditExpenseCategory: (category) => edited = category,
        onEditIncomeCategory: (category) => edited = category,
      ),
    );

    expect(find.text('Expense Categories'), findsOneWidget);
    expect(find.text('Income Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pump();
    expect(edited, fixture.provider.getExpenseCategoryById(1));
  });

  testWidgets('debt profiles screen shows empty and populated states', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);

    await _pumpScreen(tester, fixture, const DebtProfilesScreen());
    expect(find.text('Debts & Loans'), findsOneWidget);
    expect(find.text('No debt profiles yet'), findsOneWidget);

    await tester.runAsync(
      () => fixture.provider.createDebtProfile(
        name: 'Mina',
        initialBalanceCents: 1250,
      ),
    );
    await tester.pumpAndSettle();

    final profile = fixture.provider.debtProfiles.single;
    expect(find.text('Mina'), findsOneWidget);
    expect(find.byKey(Key('debt-profile-${profile.id}')), findsOneWidget);
    expect(find.byKey(Key('debt-balance-${profile.id}')), findsOneWidget);
    expect(find.text(r'+$12.50'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'I Gave'));
    await tester.pumpAndSettle();
    expect(find.text('I Gave'), findsWidgets);
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('subscriptions screen shows empty and populated states', (
    tester,
  ) async {
    final fixture = await _createFixture(
      tester,
      clock: () => DateTime(2026, 1, 10),
    );

    await _pumpScreen(tester, fixture, const SubscriptionsScreen());
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('No subscriptions yet'), findsOneWidget);

    await tester.runAsync(
      () => fixture.provider.createSubscription(
        name: 'Music',
        priceCents: 999,
        period: SubscriptionPeriod.monthly,
        firstRenewalDate: DateTime(2026, 2, 10),
      ),
    );
    await tester.pumpAndSettle();

    final subscription = fixture.provider.subscriptions.single;
    expect(find.text('Music'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(Key('subscription-${subscription.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('subscription-${subscription.id}')));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });
}

Future<TestFixture> _createFixture(
  WidgetTester tester, {
  DateTime Function()? clock,
}) async {
  final fixture = (await tester.runAsync(() => TestFixture.create(clock: clock)))!;
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
  await tester.pumpAndSettle();
}
