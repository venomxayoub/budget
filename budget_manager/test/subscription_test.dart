import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:budget_manager/models/subscription.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late DatabaseHelper databaseHelper;
  late TransactionProvider provider;
  late DateTime now;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'budget_subscription_test_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      path: path.join(temporaryDirectory.path, 'budget.db'),
    );
    now = DateTime(2026, 1, 10, 9);
    provider = TransactionProvider(
      databaseHelper: databaseHelper,
      clock: () => now,
    );
    await provider.loadData();
  });

  tearDown(() async {
    await databaseHelper.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('creation charges now and preserves a future first renewal', () async {
    await provider.createSubscription(
      name: 'Streaming',
      priceCents: 1299,
      period: SubscriptionPeriod.monthly,
      firstRenewalDate: DateTime(2026, 2, 5),
    );

    final subscription = provider.subscriptions.single;
    final payment = provider.subscriptionPayments(subscription.id!).single;
    expect(subscription.nextRenewalDate, DateTime(2026, 2, 5));
    expect(payment.amountCents, 1299);
    expect(payment.note, 'Streaming');
    expect(payment.createdAt, DateTime(2026, 1, 10));
    expect(payment.subscriptionScheduledDate, DateTime(2026, 1, 10));
    expect(
      provider.expenseCategoryMap[payment.categoryIds.single]?.name,
      'Subscription',
    );
  });

  test('creation due today charges once and advances the schedule', () async {
    await provider.createSubscription(
      name: 'Weekly plan',
      priceCents: 500,
      period: SubscriptionPeriod.weekly,
      firstRenewalDate: DateTime(2026, 1, 10),
    );

    expect(provider.entries, hasLength(1));
    expect(
      provider.subscriptions.single.nextRenewalDate,
      DateTime(2026, 1, 17),
    );
  });

  test('editing fields and schedule does not charge', () async {
    await provider.createSubscription(
      name: 'Before',
      priceCents: 1000,
      period: SubscriptionPeriod.monthly,
      firstRenewalDate: DateTime(2026, 2, 10),
    );
    final id = provider.subscriptions.single.id!;

    await provider.updateSubscription(
      id: id,
      name: 'After',
      priceCents: 1500,
      period: SubscriptionPeriod.annual,
      nextRenewalDate: DateTime(2026, 1, 10),
    );

    final subscription = provider.subscriptions.single;
    expect(provider.subscriptionPayments(id), hasLength(1));
    expect(subscription.name, 'After');
    expect(subscription.priceCents, 1500);
    expect(subscription.period, SubscriptionPeriod.annual);
    expect(subscription.nextRenewalDate, DateTime(2026, 1, 10));
    expect(subscription.renewalAnchorDate, DateTime(2026, 1, 10));
  });

  test('same-day reactivation is a distinct immediate charge', () async {
    await provider.createSubscription(
      name: 'Same day',
      priceCents: 300,
      period: SubscriptionPeriod.weekly,
      firstRenewalDate: DateTime(2026, 2, 10),
    );
    final id = provider.subscriptions.single.id!;

    await provider.pauseSubscription(id);
    await provider.reactivateSubscription(id);
    await provider.cancelSubscription(id);
    await provider.reactivateSubscription(id);

    expect(provider.subscriptionPayments(id), hasLength(3));
  });

  test('pause and cancel stop charging; reactivation charges today', () async {
    await provider.createSubscription(
      name: 'Membership',
      priceCents: 2000,
      period: SubscriptionPeriod.monthly,
      firstRenewalDate: DateTime(2026, 2, 10),
    );
    final id = provider.subscriptions.single.id!;

    await provider.pauseSubscription(id);
    now = DateTime(2026, 4, 10, 9);
    await provider.processSubscriptionsIfNeeded();
    expect(provider.subscriptionPayments(id), hasLength(1));

    await provider.reactivateSubscription(id);
    expect(provider.subscriptionPayments(id), hasLength(2));
    expect(provider.subscriptions.single.status, SubscriptionStatus.active);
    expect(
      provider.subscriptions.single.nextRenewalDate,
      DateTime(2026, 5, 10),
    );

    await provider.cancelSubscription(id);
    now = DateTime(2026, 6, 10, 9);
    await provider.processSubscriptionsIfNeeded();
    expect(provider.subscriptionPayments(id), hasLength(2));

    await provider.reactivateSubscription(id);
    expect(provider.subscriptionPayments(id), hasLength(3));
    expect(
      provider.subscriptionStatusEvents(id).map((event) => event.toStatus),
      containsAll(<SubscriptionStatus>[
        SubscriptionStatus.paused,
        SubscriptionStatus.cancelled,
        SubscriptionStatus.active,
      ]),
    );
  });

  test(
    'daily processing catches up all renewals and remains idempotent',
    () async {
      await provider.createSubscription(
        name: 'Weekly',
        priceCents: 250,
        period: SubscriptionPeriod.weekly,
        firstRenewalDate: DateTime(2026, 1, 17),
      );

      now = DateTime(2026, 2, 8, 8);
      await provider.processSubscriptionsIfNeeded();
      final id = provider.subscriptions.single.id!;
      expect(
        provider
            .subscriptionPayments(id)
            .map((payment) => payment.subscriptionScheduledDate),
        containsAll(<DateTime>[
          DateTime(2026, 1, 10),
          DateTime(2026, 1, 17),
          DateTime(2026, 1, 24),
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 7),
        ]),
      );

      await provider.processSubscriptionsIfNeeded();
      expect(provider.subscriptionPayments(id), hasLength(5));

      final reloaded = TransactionProvider(
        databaseHelper: databaseHelper,
        clock: () => now,
      );
      await reloaded.loadData();
      expect(reloaded.subscriptionPayments(id), hasLength(5));
    },
  );

  test('month-end and leap-day anchors do not drift', () async {
    await provider.createSubscription(
      name: 'Month end',
      priceCents: 100,
      period: SubscriptionPeriod.monthly,
      firstRenewalDate: DateTime(2026, 1, 31),
    );
    final monthlyId = provider.subscriptions.single.id!;

    now = DateTime(2026, 3, 31, 9);
    await provider.processSubscriptionsIfNeeded();
    expect(
      provider
          .subscriptionPayments(monthlyId)
          .map((payment) => payment.subscriptionScheduledDate),
      containsAll(<DateTime>[DateTime(2026, 2, 28), DateTime(2026, 3, 31)]),
    );

    await provider.createSubscription(
      name: 'Leap',
      priceCents: 100,
      period: SubscriptionPeriod.annual,
      firstRenewalDate: DateTime(2028, 2, 29),
    );
    final annualId = provider.subscriptions.last.id!;
    now = DateTime(2032, 3, 1, 9);
    await provider.processSubscriptionsIfNeeded();
    expect(
      provider
          .subscriptionPayments(annualId)
          .map((payment) => payment.subscriptionScheduledDate),
      containsAll(<DateTime>[
        DateTime(2028, 2, 29),
        DateTime(2029, 2, 28),
        DateTime(2030, 2, 28),
        DateTime(2031, 2, 28),
        DateTime(2032, 2, 29),
      ]),
    );
  });

  test(
    'subscription payments share the existing entry archive lifecycle',
    () async {
      await provider.createSubscription(
        name: 'Shared payment',
        priceCents: 750,
        period: SubscriptionPeriod.monthly,
        firstRenewalDate: DateTime(2026, 2, 10),
      );
      final subscriptionId = provider.subscriptions.single.id!;
      final expenseId =
          provider.subscriptionPayments(subscriptionId).single.id!;

      await provider.deleteExpense(expenseId);
      expect(provider.entries, isEmpty);
      expect(provider.subscriptionPayments(subscriptionId), isEmpty);

      await provider.restoreExpense(expenseId);
      expect(provider.entries, hasLength(1));
      expect(provider.subscriptionPayments(subscriptionId), hasLength(1));

      await provider.deleteExpense(expenseId);
      await provider.permanentDeleteExpense(expenseId);
      expect(provider.subscriptionPayments(subscriptionId), isEmpty);
    },
  );
}
