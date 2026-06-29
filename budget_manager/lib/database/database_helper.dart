import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/debt_profile.dart';
import '../models/debt_transaction.dart';
import '../models/subscription.dart';
import '../models/subscription_status_event.dart';

const _legacyExternalDbDir = '/storage/emulated/0/budget_manager';
const _dbFileName = 'budget_manager.db';
const _backupFileName = 'budget_manager_backup.db';
const _databaseVersion = 6;

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
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    return openDatabase(
      path,
      version: _databaseVersion,
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
        deleted_at TEXT,
        subscription_id INTEGER,
        subscription_scheduled_date TEXT,
        subscription_charge_key TEXT
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

    await _createDebtTables(db);
    await _createSubscriptionTables(db);
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
      if (await _hasColumn(txn, 'expenses', 'price')) {
        await _rebuildEntryTable(txn, 'expenses');
      }
      if (await _hasColumn(txn, 'incomes', 'price')) {
        await _rebuildEntryTable(txn, 'incomes');
      }
      if (oldVersion < 5) {
        await _createDebtTables(txn);
      }
      if (oldVersion < 6) {
        if (!await _hasColumn(txn, 'expenses', 'subscription_id')) {
          await txn.execute(
            'ALTER TABLE expenses ADD COLUMN subscription_id INTEGER',
          );
        }
        if (!await _hasColumn(txn, 'expenses', 'subscription_scheduled_date')) {
          await txn.execute(
            'ALTER TABLE expenses ADD COLUMN subscription_scheduled_date TEXT',
          );
        }
        if (!await _hasColumn(txn, 'expenses', 'subscription_charge_key')) {
          await txn.execute(
            'ALTER TABLE expenses ADD COLUMN subscription_charge_key TEXT',
          );
        }
        await _createSubscriptionTables(txn);
      }
    });
  }

  Future<void> _createDebtTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        initial_balance_cents INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('gave', 'received', 'update')),
        amount_cents INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (profile_id) REFERENCES debt_profiles (id),
        CHECK (type = 'update' OR amount_cents > 0)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_debt_transactions_profile_chronological
      ON debt_transactions (profile_id, created_at, id)
    ''');
  }

  Future<void> _createSubscriptionTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price_cents INTEGER NOT NULL CHECK (price_cents > 0),
        period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'annual')),
        status TEXT NOT NULL CHECK (status IN ('active', 'paused', 'cancelled')),
        renewal_anchor_date TEXT NOT NULL,
        next_renewal_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscription_status_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscription_id INTEGER NOT NULL,
        from_status TEXT,
        to_status TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        FOREIGN KEY (subscription_id) REFERENCES subscriptions (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_subscription_charge
      ON expenses (subscription_charge_key)
      WHERE subscription_charge_key IS NOT NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_subscription_status_events_history
      ON subscription_status_events (subscription_id, occurred_at, id)
    ''');
  }

  Future<void> _rebuildEntryTable(DatabaseExecutor db, String table) async {
    final replacement = '${table}_v4';
    await db.execute('DROP TABLE IF EXISTS $replacement');
    await db.execute('''
      CREATE TABLE $replacement (
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
      INSERT INTO $replacement (
        id,
        category_ids,
        price_cents,
        note,
        created_at,
        updated_at,
        deleted_at
      )
      SELECT
        id,
        category_ids,
        CAST(price_cents AS INTEGER),
        note,
        created_at,
        updated_at,
        deleted_at
      FROM $table
    ''');
    await db.execute('DROP TABLE $table');
    await db.execute('ALTER TABLE $replacement RENAME TO $table');
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
    final values = category.toMap()..remove('id');
    values['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'expense_categories',
      values,
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
    final values = category.toMap()..remove('id');
    values['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'income_categories',
      values,
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
    final values = expense.toMap()..remove('id');
    values['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'expenses',
      values,
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
    final values = income.toMap()..remove('id');
    values['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'incomes',
      values,
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

  Future<int> insertDebtProfile(DebtProfile profile) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final values = profile.toMap()..remove('id');
    values['created_at'] = profile.createdAt?.toIso8601String() ?? now;
    values['updated_at'] = profile.updatedAt?.toIso8601String() ?? now;
    return db.insert('debt_profiles', values);
  }

  Future<List<DebtProfile>> getDebtProfiles() async {
    final db = await database;
    final maps = await db.query(
      'debt_profiles',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC, id DESC',
    );
    return maps.map(DebtProfile.fromMap).toList();
  }

  Future<List<DebtProfile>> getArchivedDebtProfiles() async {
    final db = await database;
    final maps = await db.query(
      'debt_profiles',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, id DESC',
    );
    return maps.map(DebtProfile.fromMap).toList();
  }

  Future<int> renameDebtProfile(int id, String name) async {
    final db = await database;
    return db.update(
      'debt_profiles',
      {'name': name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<int> softDeleteDebtProfile(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.update(
      'debt_profiles',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<int> restoreDebtProfile(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.update(
      'debt_profiles',
      {'deleted_at': null, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NOT NULL',
      whereArgs: [id],
    );
  }

  Future<int> insertDebtTransaction(DebtTransaction transaction) async {
    final db = await database;
    return db.transaction((txn) async {
      final profile = await txn.query(
        'debt_profiles',
        columns: const ['id'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [transaction.profileId],
        limit: 1,
      );
      if (profile.isEmpty) {
        throw StateError('The debt profile no longer exists.');
      }

      final now = DateTime.now().toIso8601String();
      final values = transaction.toMap()..remove('id');
      values['created_at'] = transaction.createdAt?.toIso8601String() ?? now;
      values['updated_at'] = transaction.updatedAt?.toIso8601String() ?? now;
      final id = await txn.insert('debt_transactions', values);
      await txn.update(
        'debt_profiles',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [transaction.profileId],
      );
      return id;
    });
  }

  Future<List<DebtTransaction>> getDebtTransactions({int? profileId}) async {
    final db = await database;
    final maps = await db.query(
      'debt_transactions',
      where:
          profileId == null
              ? 'deleted_at IS NULL'
              : 'profile_id = ? AND deleted_at IS NULL',
      whereArgs: profileId == null ? null : [profileId],
      orderBy: 'created_at ASC, id ASC',
    );
    return maps.map(DebtTransaction.fromMap).toList();
  }

  Future<int> softDeleteDebtTransaction(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'debt_transactions',
        columns: const ['profile_id'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final now = DateTime.now().toIso8601String();
      final affected = await txn.update(
        'debt_transactions',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      await txn.update(
        'debt_profiles',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [rows.single['profile_id']],
      );
      return affected;
    });
  }

  Future<int> calculateDebtBalance(int profileId) async {
    final db = await database;
    final profiles = await db.query(
      'debt_profiles',
      columns: const ['initial_balance_cents'],
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (profiles.isEmpty) {
      throw StateError('The debt profile no longer exists.');
    }

    var balance = (profiles.single['initial_balance_cents'] as num).toInt();
    final transactions = await getDebtTransactions(profileId: profileId);
    for (final transaction in transactions) {
      balance = switch (transaction.type) {
        DebtTransactionType.gave => balance + transaction.amountCents,
        DebtTransactionType.received => balance - transaction.amountCents,
        DebtTransactionType.update => transaction.amountCents,
      };
    }
    return balance;
  }

  Future<List<Subscription>> getSubscriptions() async {
    final db = await database;
    final maps = await db.query(
      'subscriptions',
      orderBy:
          "CASE status WHEN 'active' THEN 0 ELSE 1 END, "
          'next_renewal_date ASC, updated_at DESC, id DESC',
    );
    return maps.map(Subscription.fromMap).toList();
  }

  Future<List<SubscriptionStatusEvent>> getSubscriptionStatusEvents() async {
    final db = await database;
    final maps = await db.query(
      'subscription_status_events',
      orderBy: 'occurred_at DESC, id DESC',
    );
    return maps.map(SubscriptionStatusEvent.fromMap).toList();
  }

  Future<int> createSubscription({
    required Subscription subscription,
    required DateTime today,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final values = subscription.toMap()..remove('id');
      final id = await txn.insert('subscriptions', values);
      final eventId = await txn.insert(
        'subscription_status_events',
        SubscriptionStatusEvent(
            subscriptionId: id,
            fromStatus: null,
            toStatus: SubscriptionStatus.active,
            occurredAt: subscription.createdAt ?? today,
          ).toMap()
          ..remove('id'),
      );
      await _insertSubscriptionPayment(
        txn,
        subscription: subscription.copyWith(id: id),
        scheduledDate: today,
        now: subscription.createdAt ?? today,
        chargeKey: 'creation:$id:$eventId',
      );

      if (!_dateOnly(subscription.nextRenewalDate).isAfter(_dateOnly(today))) {
        final next = _advanceRenewal(
          subscription.nextRenewalDate,
          subscription.renewalAnchorDate,
          subscription.period,
        );
        await txn.update(
          'subscriptions',
          {
            'next_renewal_date': _dateToStorage(next),
            'updated_at': (subscription.updatedAt ?? today).toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    });
  }

  Future<int> updateSubscription(Subscription subscription) async {
    final db = await database;
    final values = subscription.toMap()..remove('id');
    return db.update(
      'subscriptions',
      values,
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  Future<void> changeSubscriptionStatus({
    required int id,
    required SubscriptionStatus status,
    required DateTime now,
    required bool chargeImmediately,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subscriptions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('The subscription no longer exists.');
      }
      final current = Subscription.fromMap(rows.single);
      if (current.status == status) return;

      final today = _dateOnly(now);
      var updated = current.copyWith(status: status, updatedAt: now);
      if (chargeImmediately) {
        updated = updated.copyWith(
          renewalAnchorDate: today,
          nextRenewalDate: _advanceRenewal(today, today, current.period),
        );
      }
      final values = updated.toMap()..remove('id');
      final affected = await txn.update(
        'subscriptions',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (affected != 1) {
        throw StateError('The subscription no longer exists.');
      }
      final eventId = await txn.insert(
        'subscription_status_events',
        SubscriptionStatusEvent(
            subscriptionId: id,
            fromStatus: current.status,
            toStatus: status,
            occurredAt: now,
          ).toMap()
          ..remove('id'),
      );
      if (chargeImmediately) {
        await _insertSubscriptionPayment(
          txn,
          subscription: updated,
          scheduledDate: today,
          now: now,
          chargeKey: 'reactivation:$id:$eventId',
        );
      }
    });
  }

  Future<bool> processSubscriptionsIfNeeded(DateTime now) async {
    final db = await database;
    final today = _dateOnly(now);
    final todayKey = _dateToStorage(today);
    return db.transaction((txn) async {
      final metadata = await txn.query(
        'app_metadata',
        columns: const ['value'],
        where: 'key = ?',
        whereArgs: const ['last_subscription_check_date'],
        limit: 1,
      );
      if (metadata.isNotEmpty && metadata.single['value'] == todayKey) {
        return false;
      }

      final rows = await txn.query(
        'subscriptions',
        where: "status = 'active' AND next_renewal_date <= ?",
        whereArgs: [todayKey],
        orderBy: 'next_renewal_date ASC, id ASC',
      );
      for (final row in rows) {
        var subscription = Subscription.fromMap(row);
        var dueDate = _dateOnly(subscription.nextRenewalDate);
        while (!dueDate.isAfter(today)) {
          final chargeKey =
              'renewal:${subscription.id}:${_dateToStorage(dueDate)}';
          final existing = await txn.query(
            'expenses',
            columns: const ['id'],
            where: 'subscription_charge_key = ?',
            whereArgs: [chargeKey],
            limit: 1,
          );
          if (existing.isEmpty) {
            await _insertSubscriptionPayment(
              txn,
              subscription: subscription,
              scheduledDate: dueDate,
              now: now,
              chargeKey: chargeKey,
            );
          }
          dueDate = _advanceRenewal(
            dueDate,
            subscription.renewalAnchorDate,
            subscription.period,
          );
        }
        subscription = subscription.copyWith(
          nextRenewalDate: dueDate,
          updatedAt: now,
        );
        await txn.update(
          'subscriptions',
          subscription.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [subscription.id],
        );
      }

      await txn.insert('app_metadata', {
        'key': 'last_subscription_check_date',
        'value': todayKey,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<void> _insertSubscriptionPayment(
    DatabaseExecutor db, {
    required Subscription subscription,
    required DateTime scheduledDate,
    required DateTime now,
    required String chargeKey,
  }) async {
    final categoryId = await _ensureSubscriptionCategory(db, now);
    await db.insert('expenses', {
      'category_ids': '[$categoryId]',
      'price_cents': subscription.priceCents,
      'note': subscription.name,
      'created_at': _dateOnly(scheduledDate).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'deleted_at': null,
      'subscription_id': subscription.id,
      'subscription_scheduled_date': _dateToStorage(scheduledDate),
      'subscription_charge_key': chargeKey,
    });
  }

  Future<int> _ensureSubscriptionCategory(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final existing = await db.query(
      'expense_categories',
      columns: const ['id'],
      where: 'LOWER(TRIM(name)) = ?',
      whereArgs: const ['subscription'],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id'] as int;
    return db.insert('expense_categories', {
      'name': 'Subscription',
      'emoji': '🔁',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateToStorage(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _advanceRenewal(
  DateTime current,
  DateTime anchor,
  SubscriptionPeriod period,
) {
  switch (period) {
    case SubscriptionPeriod.weekly:
      return _dateOnly(current).add(const Duration(days: 7));
    case SubscriptionPeriod.monthly:
      final firstOfFollowingMonth = DateTime(current.year, current.month + 1);
      final lastDay =
          DateTime(
            firstOfFollowingMonth.year,
            firstOfFollowingMonth.month + 1,
            0,
          ).day;
      final day = anchor.day > lastDay ? lastDay : anchor.day;
      return DateTime(
        firstOfFollowingMonth.year,
        firstOfFollowingMonth.month,
        day,
      );
    case SubscriptionPeriod.annual:
      final year = current.year + 1;
      final lastDay = DateTime(year, anchor.month + 1, 0).day;
      final day = anchor.day > lastDay ? lastDay : anchor.day;
      return DateTime(year, anchor.month, day);
  }
}
