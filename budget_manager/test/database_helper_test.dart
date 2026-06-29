import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:budget_manager/models/expense.dart';
import 'package:budget_manager/models/expense_category.dart';
import 'package:budget_manager/models/debt_profile.dart';
import 'package:budget_manager/models/debt_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'budget_manager_test_',
    );
    databasePath = path.join(temporaryDirectory.path, 'budget.db');
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  test('fresh database has entry, debt, and subscription schema', () async {
    final helper = _testHelper(databasePath);
    final database = await helper.database;

    final columns = await database.rawQuery('PRAGMA table_info(expenses)');
    final names = columns.map((column) => column['name']).toSet();

    expect(
      names,
      containsAll(<String>{
        'deleted_at',
        'price_cents',
        'subscription_id',
        'subscription_scheduled_date',
        'subscription_charge_key',
      }),
    );

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      tables.map((table) => table['name']),
      containsAll(<String>{
        'debt_profiles',
        'debt_transactions',
        'subscriptions',
        'subscription_status_events',
        'app_metadata',
      }),
    );
    await helper.close();
  });

  test('version 4 migration adds later tables without changing data', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (database, _) async {
          await _createVersion4Database(database);
        },
      ),
    );
    await legacy.close();

    final helper = _testHelper(databasePath);
    final database = await helper.database;
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(
      tables.map((table) => table['name']),
      containsAll(<String>{
        'debt_profiles',
        'debt_transactions',
        'subscriptions',
        'subscription_status_events',
        'app_metadata',
      }),
    );
    expect((await helper.getExpenseCategories()).single.name, 'Food');
    expect((await helper.getIncomeCategories()).single.name, 'Salary');
    expect((await helper.getExpenses()).single.note, 'Existing expense');
    expect((await helper.getArchivedIncomes()).single.note, 'Archived income');
    await helper.close();
  });

  test(
    'debt balance replays transactions and ignores soft deletions',
    () async {
      final helper = _testHelper(databasePath);
      final profileId = await helper.insertDebtProfile(
        DebtProfile(
          name: 'Sam',
          initialBalanceCents: -1000,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      final gaveId = await helper.insertDebtTransaction(
        DebtTransaction(
          profileId: profileId,
          type: DebtTransactionType.gave,
          amountCents: 1500,
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      final updateId = await helper.insertDebtTransaction(
        DebtTransaction(
          profileId: profileId,
          type: DebtTransactionType.update,
          amountCents: -200,
          note: 'Reconciled',
          createdAt: DateTime(2026, 1, 3),
        ),
      );
      final receivedId = await helper.insertDebtTransaction(
        DebtTransaction(
          profileId: profileId,
          type: DebtTransactionType.received,
          amountCents: 300,
          createdAt: DateTime(2026, 1, 4),
        ),
      );

      expect(await helper.calculateDebtBalance(profileId), -500);

      await helper.softDeleteDebtTransaction(gaveId);
      expect(await helper.calculateDebtBalance(profileId), -500);

      await helper.softDeleteDebtTransaction(receivedId);
      expect(await helper.calculateDebtBalance(profileId), -200);

      await helper.softDeleteDebtTransaction(updateId);
      expect(await helper.calculateDebtBalance(profileId), -1000);
      expect(await helper.getDebtTransactions(profileId: profileId), isEmpty);
      await helper.close();
    },
  );

  test('version 2 database is rebuilt and remains writable', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_ids TEXT NOT NULL,
              price REAL NOT NULL,
              note TEXT NOT NULL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE incomes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_ids TEXT NOT NULL,
              price REAL NOT NULL,
              note TEXT NOT NULL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          await database.insert('expenses', {
            'category_ids': '[1]',
            'price': 12.34,
            'note': 'Legacy expense',
            'created_at': DateTime(2025).toIso8601String(),
            'updated_at': DateTime(2025).toIso8601String(),
          });
        },
      ),
    );
    await legacy.close();

    final helper = _testHelper(databasePath);
    final expenses = await helper.getExpenses();
    final insertedId = await helper.insertExpense(_expense('After migration'));
    final columns = await (await helper.database).rawQuery(
      'PRAGMA table_info(expenses)',
    );
    final columnNames = columns.map((column) => column['name']).toSet();

    expect(expenses.single.amountCents, 1234);
    expect(expenses.single.deletedAt, isNull);
    expect(insertedId, greaterThan(expenses.single.id!));
    expect(columnNames, isNot(contains('price')));
    await helper.close();
  });

  test('version 3 database with legacy price constraint is repaired', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, _) async {
          await _createVersion3EntryTable(database, 'expenses');
          await _createVersion3EntryTable(database, 'incomes');
          await database.insert('expenses', {
            'category_ids': '[1]',
            'price': 12.34,
            'price_cents': 1234,
            'note': 'Version 3 expense',
            'created_at': DateTime(2025).toIso8601String(),
            'updated_at': DateTime(2025).toIso8601String(),
          });
        },
      ),
    );
    await legacy.close();

    final helper = _testHelper(databasePath);
    await helper.insertExpense(_expense('Writable after v4 migration'));
    final expenses = await helper.getExpenses();
    final columns = await (await helper.database).rawQuery(
      'PRAGMA table_info(expenses)',
    );

    expect(expenses, hasLength(2));
    expect(columns.map((column) => column['name']), isNot(contains('price')));
    await helper.close();
  });

  test('SQLite generates unique IDs across application restarts', () async {
    final firstSession = _testHelper(databasePath);
    final firstId = await firstSession.insertExpense(_expense('First'));
    final secondId = await firstSession.insertExpense(_expense('Second'));
    await firstSession.close();

    final secondSession = _testHelper(databasePath);
    final thirdId = await secondSession.insertExpense(_expense('Third'));
    final expenses = await secondSession.getExpenses();

    expect(<int>{firstId, secondId, thirdId}, hasLength(3));
    expect(expenses, hasLength(3));
    await secondSession.close();
  });

  test('entry and category updates persist', () async {
    final helper = _testHelper(databasePath);
    final expenseId = await helper.insertExpense(_expense('Original'));
    final categoryId = await helper.insertExpenseCategory(
      ExpenseCategory(name: 'Original', emoji: '📦'),
    );

    expect(
      await helper.updateExpense(
        Expense(
          id: expenseId,
          categoryIds: const [1],
          amountCents: 9876,
          note: 'Updated',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 2),
        ),
      ),
      1,
    );
    expect(
      await helper.updateExpenseCategory(
        ExpenseCategory(id: categoryId, name: 'Updated category', emoji: '✅'),
      ),
      1,
    );

    expect((await helper.getExpenses()).single.note, 'Updated');
    expect((await helper.getExpenses()).single.amountCents, 9876);
    expect(
      (await helper.getExpenseCategories()).single.name,
      'Updated category',
    );
    await helper.close();
  });
}

DatabaseHelper _testHelper(String databasePath) => DatabaseHelper.forTesting(
  databaseFactory: databaseFactoryFfi,
  path: databasePath,
);

Expense _expense(String note) => Expense(
  categoryIds: const [1],
  amountCents: 1234,
  note: note,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _createVersion3EntryTable(Database database, String table) =>
    database.execute('''
  CREATE TABLE $table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_ids TEXT NOT NULL,
    price REAL NOT NULL,
    note TEXT NOT NULL,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT,
    price_cents INTEGER
  )
''');

Future<void> _createVersion4Database(Database database) async {
  await database.execute('''
    CREATE TABLE expense_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE income_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      emoji TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  for (final table in const ['expenses', 'incomes']) {
    await database.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_ids TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
  }
  final timestamp = DateTime(2026).toIso8601String();
  await database.insert('expense_categories', {
    'name': 'Food',
    'emoji': '🍕',
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  await database.insert('income_categories', {
    'name': 'Salary',
    'emoji': '💰',
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  await database.insert('expenses', {
    'category_ids': '[1]',
    'price_cents': 1234,
    'note': 'Existing expense',
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  await database.insert('incomes', {
    'category_ids': '[1]',
    'price_cents': 5000,
    'note': 'Archived income',
    'created_at': timestamp,
    'updated_at': timestamp,
    'deleted_at': DateTime(2026, 2).toIso8601String(),
  });
}
