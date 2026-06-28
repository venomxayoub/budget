import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:budget_manager/models/debt_transaction.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:budget_manager/utils/debt_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late DatabaseHelper databaseHelper;
  late TransactionProvider provider;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'budget_debt_ledger_test_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      path: path.join(temporaryDirectory.path, 'budget.db'),
    );
    provider = TransactionProvider(databaseHelper: databaseHelper);
    await provider.loadData();
  });

  tearDown(() async {
    await databaseHelper.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'profiles accept signed initial balances and use required colors',
    () async {
      await provider.createDebtProfile(
        name: 'Negative',
        initialBalanceCents: -1,
      );
      await provider.createDebtProfile(name: 'Zero', initialBalanceCents: 0);
      await provider.createDebtProfile(
        name: 'Positive',
        initialBalanceCents: 1,
      );

      int balanceOf(String name) {
        final profile = provider.debtProfiles.singleWhere(
          (p) => p.name == name,
        );
        return provider.debtBalanceForProfile(profile.id!);
      }

      expect(balanceOf('Negative'), -1);
      expect(balanceOf('Zero'), 0);
      expect(balanceOf('Positive'), 1);
      expect(debtBalanceColor(balanceOf('Negative')), Colors.red);
      expect(debtBalanceColor(balanceOf('Zero')), Colors.green);
      expect(debtBalanceColor(balanceOf('Positive')), Colors.blue);
    },
  );

  test('gave, received, update, and deletion replay the ledger', () async {
    await provider.createDebtProfile(
      name: 'Ledger',
      initialBalanceCents: -1000,
    );
    final profile = provider.debtProfiles.single;

    await provider.addDebtTransaction(
      profileId: profile.id!,
      type: DebtTransactionType.gave,
      amountCents: 1500,
    );
    expect(provider.debtBalanceForProfile(profile.id!), 500);

    await provider.addDebtTransaction(
      profileId: profile.id!,
      type: DebtTransactionType.received,
      amountCents: 300,
    );
    expect(provider.debtBalanceForProfile(profile.id!), 200);

    await provider.addDebtTransaction(
      profileId: profile.id!,
      type: DebtTransactionType.update,
      amountCents: -200,
      note: 'Manual reconciliation',
    );
    expect(provider.debtBalanceForProfile(profile.id!), -200);

    final chronological =
        provider.debtTransactionsForProfile(profile.id!).reversed.toList();
    expect(
      chronological.map((transaction) => transaction.type),
      <DebtTransactionType>[
        DebtTransactionType.gave,
        DebtTransactionType.received,
        DebtTransactionType.update,
      ],
    );
    expect(provider.balanceBeforeDebtTransaction(chronological.last), 200);

    await provider.deleteDebtTransaction(chronological.first.id!);
    expect(provider.debtBalanceForProfile(profile.id!), -200);

    await provider.addDebtTransaction(
      profileId: profile.id!,
      type: DebtTransactionType.received,
      amountCents: 300,
    );
    expect(provider.debtBalanceForProfile(profile.id!), -500);
    final newest = provider.debtTransactionsForProfile(profile.id!).first;
    await provider.deleteDebtTransaction(newest.id!);
    expect(provider.debtBalanceForProfile(profile.id!), -200);
  });

  test('rename and archive restoration persist intact history', () async {
    await provider.createDebtProfile(name: 'Before', initialBalanceCents: 100);
    final id = provider.debtProfiles.single.id!;
    await provider.addDebtTransaction(
      profileId: id,
      type: DebtTransactionType.gave,
      amountCents: 250,
      note: 'Kept history',
    );
    await provider.renameDebtProfile(id, 'After');
    await provider.deleteDebtProfile(id);

    expect(provider.debtProfiles, isEmpty);
    expect(provider.archivedDebtProfiles.single.name, 'After');
    expect(provider.debtTransactionsForProfile(id).single.note, 'Kept history');

    await provider.restoreDebtProfile(id);
    expect(provider.debtProfiles.single.name, 'After');
    expect(provider.debtBalanceForProfile(id), 350);

    final reloaded = TransactionProvider(databaseHelper: databaseHelper);
    await reloaded.loadData();
    expect(reloaded.debtProfiles.single.name, 'After');
    expect(reloaded.debtTransactionsForProfile(id), hasLength(1));
    expect(reloaded.debtBalanceForProfile(id), 350);
  });
}
