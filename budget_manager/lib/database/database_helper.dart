import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../models/expense.dart';
import '../models/income.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'budget_manager.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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
        price REAL NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_ids TEXT NOT NULL,
        price REAL NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<int> insertExpenseCategory(ExpenseCategory category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('expense_categories', {
      ...category.toMap(),
      'created_at': now,
      'updated_at': now,
    });
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
      {
        ...category.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
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
    return await db.insert('income_categories', {
      ...category.toMap(),
      'created_at': now,
      'updated_at': now,
    });
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
      {
        ...category.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
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
    return await db.insert('expenses', {
      ...expense.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final maps = await db.query('expenses', orderBy: 'created_at DESC');
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      {
        ...expense.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertIncome(Income income) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('incomes', {
      ...income.toMap(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Income>> getIncomes() async {
    final db = await database;
    final maps = await db.query('incomes', orderBy: 'created_at DESC');
    return maps.map((map) => Income.fromMap(map)).toList();
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    return await db.update(
      'incomes',
      {
        ...income.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return await db.delete(
      'incomes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
