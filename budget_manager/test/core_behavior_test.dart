import 'package:budget_manager/models/debt_transaction.dart';
import 'package:budget_manager/models/expense.dart';
import 'package:budget_manager/models/expense_category.dart';
import 'package:budget_manager/models/income.dart';
import 'package:budget_manager/models/income_category.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_fixture.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late TestFixture fixture;
  late TransactionProvider provider;

  setUp(() async {
    fixture = await TestFixture.create();
    provider = fixture.provider;
  });

  tearDown(() => fixture.dispose());

  test('a fresh app seeds separate expense and income category sets', () {
    expect(
      provider.expenseCategories.map((category) => category.name),
      containsAll(<String>['Food', 'Transport', 'Bills', 'Other']),
    );
    expect(
      provider.incomeCategories.map((category) => category.name),
      containsAll(<String>['Salary', 'Freelance', 'Refund', 'Other']),
    );
    expect(
      provider.expenseCategories.every(
        (category) => category.id != null && category.emoji.isNotEmpty,
      ),
      isTrue,
    );
    expect(
      provider.incomeCategories.every(
        (category) => category.id != null && category.emoji.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('entries mix incomes and expenses in newest-first order', () async {
    final foodId =
        provider.expenseCategories
            .singleWhere((category) => category.name == 'Food')
            .id!;
    final salaryId =
        provider.incomeCategories
            .singleWhere((category) => category.name == 'Salary')
            .id!;
    await provider.addExpense(
      Expense(
        categoryIds: [foodId],
        amountCents: 1250,
        note: 'Lunch',
        createdAt: DateTime(2026, 1, 2, 12),
      ),
    );
    await provider.addIncome(
      Income(
        categoryIds: [salaryId],
        amountCents: 500000,
        note: 'January salary',
        createdAt: DateTime(2026, 1, 3, 9),
      ),
    );

    expect(provider.entries, hasLength(2));
    expect(provider.entries.first.isExpense, isFalse);
    expect(provider.entries.first.note, 'January salary');
    expect(provider.entries.last.isExpense, isTrue);
    expect(provider.entries.last.note, 'Lunch');
    expect(provider.entries.last.categoryIds, [foodId]);
  });

  test(
    'entry edits persist while preserving identity and creation date',
    () async {
      final otherId =
          provider.expenseCategories
              .singleWhere((category) => category.name == 'Other')
              .id!;
      final createdAt = DateTime(2026, 2, 1, 8);
      await provider.addExpense(
        Expense(
          categoryIds: [otherId],
          amountCents: 100,
          note: 'Before',
          createdAt: createdAt,
        ),
      );
      final original = provider.entries.single;

      await provider.updateExpense(
        Expense(
          id: original.id,
          categoryIds: [otherId],
          amountCents: 275,
          note: 'After',
          createdAt: original.createdAt,
        ),
      );

      final updated = provider.entries.single;
      expect(updated.id, original.id);
      expect(updated.createdAt, createdAt);
      expect(updated.amountCents, 275);
      expect(updated.note, 'After');

      final reloaded = TransactionProvider(
        databaseHelper: fixture.databaseHelper,
      );
      await reloaded.loadData();
      expect(reloaded.entries.single.id, original.id);
      expect(reloaded.entries.single.createdAt, createdAt);
      expect(reloaded.entries.single.amountCents, 275);
    },
  );

  test('expense and income use the complete archive lifecycle', () async {
    final expenseCategory = provider.expenseCategories.first.id!;
    final incomeCategory = provider.incomeCategories.first.id!;
    await provider.addExpense(
      Expense(
        categoryIds: [expenseCategory],
        amountCents: 1000,
        note: 'Expense',
      ),
    );
    await provider.addIncome(
      Income(categoryIds: [incomeCategory], amountCents: 2000, note: 'Income'),
    );
    final expenseId =
        provider.entries.singleWhere((entry) => entry.isExpense).id;
    final incomeId =
        provider.entries.singleWhere((entry) => !entry.isExpense).id;

    await provider.deleteExpense(expenseId);
    await provider.deleteIncome(incomeId);
    expect(provider.entries, isEmpty);
    expect(provider.archivedEntries, hasLength(2));
    expect(
      provider.archivedEntries.every((entry) => entry.deletedAt != null),
      isTrue,
    );

    await provider.restoreExpense(expenseId);
    await provider.restoreIncome(incomeId);
    expect(provider.entries, hasLength(2));
    expect(provider.archivedEntries, isEmpty);

    await provider.deleteExpense(expenseId);
    await provider.deleteIncome(incomeId);
    await provider.permanentDeleteExpense(expenseId);
    await provider.permanentDeleteIncome(incomeId);
    expect(provider.entries, isEmpty);
    expect(provider.archivedEntries, isEmpty);
    expect(await fixture.databaseHelper.getArchivedExpenses(), isEmpty);
    expect(await fixture.databaseHelper.getArchivedIncomes(), isEmpty);
  });

  test('category creation and editing stay isolated by entry type', () async {
    await provider.addExpenseCategory(
      ExpenseCategory(name: 'Utilities', emoji: '💡'),
    );
    await provider.addIncomeCategory(
      IncomeCategory(name: 'Bonus', emoji: '🎉'),
    );

    final expense = provider.expenseCategories.singleWhere(
      (category) => category.name == 'Utilities',
    );
    final income = provider.incomeCategories.singleWhere(
      (category) => category.name == 'Bonus',
    );
    expect(
      provider.incomeCategories.map((category) => category.name),
      isNot(contains('Utilities')),
    );
    expect(
      provider.expenseCategories.map((category) => category.name),
      isNot(contains('Bonus')),
    );

    await provider.updateExpenseCategory(
      expense.copyWith(name: 'Home utilities', emoji: '⚡'),
    );
    await provider.updateIncomeCategory(
      income.copyWith(name: 'Annual bonus', emoji: '🏆'),
    );
    expect(
      provider.getExpenseCategoryById(expense.id!)?.name,
      'Home utilities',
    );
    expect(provider.getIncomeCategoryById(income.id!)?.name, 'Annual bonus');
  });

  test(
    'provider rejects invalid debt operations without changing data',
    () async {
      expect(
        () => provider.createDebtProfile(name: '   ', initialBalanceCents: 0),
        throwsArgumentError,
      );
      await provider.createDebtProfile(name: 'Alex', initialBalanceCents: 0);
      final id = provider.debtProfiles.single.id!;

      expect(
        () => provider.addDebtTransaction(
          profileId: id,
          type: DebtTransactionType.gave,
          amountCents: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => provider.addDebtTransaction(
          profileId: id,
          type: DebtTransactionType.received,
          amountCents: -1,
        ),
        throwsArgumentError,
      );
      expect(provider.debtTransactionsForProfile(id), isEmpty);
    },
  );

  test(
    'absolute debt updates accept positive, zero, and negative balances',
    () async {
      await provider.createDebtProfile(
        name: 'Ledger',
        initialBalanceCents: 500,
      );
      final id = provider.debtProfiles.single.id!;

      for (final balance in <int>[1000, 0, -750]) {
        await provider.addDebtTransaction(
          profileId: id,
          type: DebtTransactionType.update,
          amountCents: balance,
        );
        expect(provider.debtBalanceForProfile(id), balance);
      }
    },
  );

  test('debt profiles are ordered by their latest activity', () async {
    await provider.createDebtProfile(name: 'First', initialBalanceCents: 0);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await provider.createDebtProfile(name: 'Second', initialBalanceCents: 0);
    final firstId =
        provider.debtProfiles
            .singleWhere((profile) => profile.name == 'First')
            .id!;

    expect(provider.debtProfiles.first.name, 'Second');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await provider.addDebtTransaction(
      profileId: firstId,
      type: DebtTransactionType.gave,
      amountCents: 100,
    );
    expect(provider.debtProfiles.first.name, 'First');
  });

  test(
    'archived debt profiles keep history but reject new mutations',
    () async {
      await provider.createDebtProfile(
        name: 'Archived',
        initialBalanceCents: 100,
      );
      final id = provider.debtProfiles.single.id!;
      await provider.addDebtTransaction(
        profileId: id,
        type: DebtTransactionType.gave,
        amountCents: 50,
        note: 'History',
      );
      await provider.deleteDebtProfile(id);

      expect(provider.debtProfiles, isEmpty);
      expect(provider.archivedDebtProfiles.single.id, id);
      expect(provider.debtTransactionsForProfile(id).single.note, 'History');
      expect(
        () => provider.addDebtTransaction(
          profileId: id,
          type: DebtTransactionType.gave,
          amountCents: 1,
        ),
        throwsStateError,
      );
      expect(() => provider.renameDebtProfile(id, 'Changed'), throwsStateError);
    },
  );

  test('missing records are not silently updated', () async {
    expect(
      () => provider.updateExpense(
        Expense(
          id: 999,
          categoryIds: const [1],
          amountCents: 100,
          note: 'Missing',
        ),
      ),
      throwsStateError,
    );
    expect(
      () => provider.updateIncome(
        Income(
          id: 999,
          categoryIds: const [1],
          amountCents: 100,
          note: 'Missing',
        ),
      ),
      throwsStateError,
    );
    expect(provider.getEntryById(id: 999, isExpense: true), isNull);
    expect(provider.getDebtProfileById(999), isNull);
  });
}
