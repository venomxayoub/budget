import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../models/expense.dart';
import '../models/income.dart';

const _legacyExternalDbDir = '/storage/emulated/0/budget_manager';
const _dbFileName = 'budget_manager.db';
const _backupFileName = 'budget_manager_backup.db';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal() : _databaseFactory = null, _overridePath = null;

  DatabaseHelper.forTesting({
    required DatabaseFactory databaseFactory,
    required String path,
  }) : _databaseFactory = databaseFactory,
       _overridePath = path;

  final DatabaseFactory? _databaseFactory;
  final String? _overridePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> importDatabase(Uint8List bytes) async {
    if (_overridePath != null) {
      throw StateError('Database import is unavailable in tests.');
    }

    final targetPath = join(await getDatabasesPath(), _dbFileName);
    final importPath = '$targetPath.import';
    final rollbackPath = '$targetPath.rollback';
    final importFile = File(importPath);
    await importFile.writeAsBytes(bytes, flush: true);

    Database? candidate;
    try {
      try {
        candidate = await openReadOnlyDatabase(importPath);
        final integrity = await candidate.rawQuery('PRAGMA integrity_check');
        if (integrity.single.values.single != 'ok') {
          throw const FormatException('The selected database is corrupted.');
        }
        final tables = await candidate.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        );
        final names = tables.map((table) => table['name']).toSet();
        const requiredTables = {
          'expense_categories',
          'income_categories',
          'expenses',
          'incomes',
        };
        if (!names.containsAll(requiredTables)) {
          throw const FormatException(
            'The selected file is not a Budget Manager database.',
          );
        }
      } finally {
        await candidate?.close();
      }
    } catch (_) {
      if (await importFile.exists()) await importFile.delete();
      rethrow;
    }

    await close();
    final target = File(targetPath);
    final rollback = File(rollbackPath);
    try {
      if (await rollback.exists()) await rollback.delete();
      if (await target.exists()) await target.rename(rollbackPath);
      await importFile.rename(targetPath);
      await database;
      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      await close();
      if (await target.exists()) await target.delete();
      if (await rollback.exists()) await rollback.rename(targetPath);
      rethrow;
    } finally {
      if (await importFile.exists()) await importFile.delete();
    }
  }

  Future<Database> _initDatabase() async {
    final path = _overridePath ?? join(await getDatabasesPath(), _dbFileName);
    final dbPath = dirname(path);

    if (_overridePath == null) {
      await Directory(dbPath).create(recursive: true);
      await _migrateLegacyExternalDatabase(path);
    }

    final backupPath = join(dbPath, _backupFileName);
    final dbFile = File(path);
    if (await dbFile.exists()) {
      try {
        await dbFile.copy(backupPath);
      } catch (_) {}
    }

    if (_databaseFactory != null) {
      return _databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _migrateLegacyExternalDatabase(String internalPath) async {
    if (!Platform.isAndroid || await File(internalPath).exists()) return;

    final legacyDatabase = File(join(_legacyExternalDbDir, _dbFileName));
    try {
      if (!await legacyDatabase.exists()) return;
      await legacyDatabase.copy(internalPath);
      await legacyDatabase.delete();
      final legacyBackup = File(join(_legacyExternalDbDir, _backupFileName));
      if (await legacyBackup.exists()) await legacyBackup.delete();
    } on FileSystemException {
      // Modern Android versions may deny access to the old shared-storage path.
      // The app continues with its private, Auto Backup-enabled database.
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE income_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_ids TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE incomes (
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      if (!await _hasColumn(txn, 'expenses', 'deleted_at')) {
        await txn.execute('ALTER TABLE expenses ADD COLUMN deleted_at TEXT');
      }
      if (!await _hasColumn(txn, 'incomes', 'deleted_at')) {
        await txn.execute('ALTER TABLE incomes ADD COLUMN deleted_at TEXT');
      }
      if (!await _hasColumn(txn, 'expenses', 'price_cents')) {
        await txn.execute(
          'ALTER TABLE expenses ADD COLUMN price_cents INTEGER',
        );
        await txn.execute(
          'UPDATE expenses SET price_cents = ROUND(price * 100)',
        );
      }
      if (!await _hasColumn(txn, 'incomes', 'price_cents')) {
        await txn.execute('ALTER TABLE incomes ADD COLUMN price_cents INTEGER');
        await txn.execute(
          'UPDATE incomes SET price_cents = ROUND(price * 100)',
        );
      }
    });
  }

  Future<bool> _hasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.any((entry) => entry['name'] == column);
  }

  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = category.toMap()..remove('id');
    values['created_at'] = category.createdAt?.toIso8601String() ?? now;
    values['updated_at'] = category.updatedAt?.toIso8601String() ?? now;
    return db.insert('expense_categories', values);
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final db = await database;
    final maps = await db.query('expense_categories', orderBy: 'name ASC');
    return maps.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  Future<int> updateExpenseCategory(ExpenseCategory category) async {
    final db = await database;
    return await db.update(
      'expense_categories',
      {...category.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteExpenseCategory(int id) async {
    final db = await database;
    return await db.delete(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertIncomeCategory(IncomeCategory category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = category.toMap()..remove('id');
    values['created_at'] = category.createdAt?.toIso8601String() ?? now;
    values['updated_at'] = category.updatedAt?.toIso8601String() ?? now;
    return db.insert('income_categories', values);
  }

  Future<List<IncomeCategory>> getIncomeCategories() async {
    final db = await database;
    final maps = await db.query('income_categories', orderBy: 'name ASC');
    return maps.map((map) => IncomeCategory.fromMap(map)).toList();
  }

  Future<int> updateIncomeCategory(IncomeCategory category) async {
    final db = await database;
    return await db.update(
      'income_categories',
      {...category.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteIncomeCategory(int id) async {
    final db = await database;
    return await db.delete(
      'income_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = expense.toMap()..remove('id');
    values['created_at'] = expense.createdAt?.toIso8601String() ?? now;
    values['updated_at'] = expense.updatedAt?.toIso8601String() ?? now;
    return db.insert('expenses', values);
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getArchivedExpenses() async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      {...expense.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> softDeleteExpense(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'expenses',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreExpense(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'expenses',
      {'deleted_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentDeleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertIncome(Income income) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = income.toMap()..remove('id');
    values['created_at'] = income.createdAt?.toIso8601String() ?? now;
    values['updated_at'] = income.updatedAt?.toIso8601String() ?? now;
    return db.insert('incomes', values);
  }

  Future<List<Income>> getIncomes() async {
    final db = await database;
    final maps = await db.query(
      'incomes',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Income.fromMap(map)).toList();
  }

  Future<List<Income>> getArchivedIncomes() async {
    final db = await database;
    final maps = await db.query(
      'incomes',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((map) => Income.fromMap(map)).toList();
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    return await db.update(
      'incomes',
      {...income.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> softDeleteIncome(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'incomes',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreIncome(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'incomes',
      {'deleted_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentDeleteIncome(int id) async {
    final db = await database;
    return await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }
}
