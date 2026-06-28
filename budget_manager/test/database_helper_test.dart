import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:budget_manager/models/expense.dart';
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

  test('fresh database has archive and integer-cent columns', () async {
    final helper = _testHelper(databasePath);
    final database = await helper.database;

    final columns = await database.rawQuery('PRAGMA table_info(expenses)');
    final names = columns.map((column) => column['name']).toSet();

    expect(names, containsAll(<String>{'deleted_at', 'price_cents'}));
    await helper.close();
  });

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
