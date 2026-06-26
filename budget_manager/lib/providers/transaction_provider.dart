import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../database/database_helper.dart';

class EntryItem {
  final int id;
  final bool isExpense;
  final double price;
  final String note;
  final List<int> categoryIds;
  final DateTime createdAt;
  final DateTime? deletedAt;

  EntryItem({
    required this.id,
    required this.isExpense,
    required this.price,
    required this.note,
    required this.categoryIds,
    required this.createdAt,
    this.deletedAt,
  });

  bool get isArchived => deletedAt != null;
}

class TransactionProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  List<ExpenseCategory> _expenseCategories = [];
  List<IncomeCategory> _incomeCategories = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Income> get incomes => List.unmodifiable(_incomes);
  List<ExpenseCategory> get expenseCategories => List.unmodifiable(_expenseCategories);
  List<IncomeCategory> get incomeCategories => List.unmodifiable(_incomeCategories);

  List<EntryItem> get entries {
    final items = <EntryItem>[
      for (final e in _expenses)
        if (e.deletedAt == null)
          EntryItem(
            id: e.id!,
            isExpense: true,
            price: e.price,
            note: e.note,
            categoryIds: e.categoryIds,
            createdAt: e.createdAt!,
          ),
      for (final i in _incomes)
        if (i.deletedAt == null)
          EntryItem(
            id: i.id!,
            isExpense: false,
            price: i.price,
            note: i.note,
            categoryIds: i.categoryIds,
            createdAt: i.createdAt!,
          ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<EntryItem> get archivedEntries {
    final items = <EntryItem>[
      for (final e in _expenses)
        if (e.deletedAt != null)
          EntryItem(
            id: e.id!,
            isExpense: true,
            price: e.price,
            note: e.note,
            categoryIds: e.categoryIds,
            createdAt: e.createdAt!,
            deletedAt: e.deletedAt,
          ),
      for (final i in _incomes)
        if (i.deletedAt != null)
          EntryItem(
            id: i.id!,
            isExpense: false,
            price: i.price,
            note: i.note,
            categoryIds: i.categoryIds,
            createdAt: i.createdAt!,
            deletedAt: i.deletedAt,
          ),
    ];
    items.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return items;
  }

  ExpenseCategory? getExpenseCategoryById(int id) {
    try {
      return _expenseCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  IncomeCategory? getIncomeCategoryById(int id) {
    try {
      return _incomeCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<int, ExpenseCategory> get expenseCategoryMap =>
      {for (final c in _expenseCategories) if (c.id != null) c.id!: c};

  Map<int, IncomeCategory> get incomeCategoryMap =>
      {for (final c in _incomeCategories) if (c.id != null) c.id!: c};

  Map<int, dynamic> getCategoryMap(bool isExpense) =>
      isExpense ? expenseCategoryMap : incomeCategoryMap;

  List<dynamic> getCategoriesList(bool isExpense) =>
      (isExpense ? _expenseCategories : _incomeCategories)
          .map((c) => c as dynamic)
          .toList();

  Future<void> loadData() async {
    _expenseCategories = defaultExpenseCategories;
    _incomeCategories = defaultIncomeCategories;

    try {
      final db = DatabaseHelper();
      _expenseCategories = await db.getExpenseCategories();
      _incomeCategories = await db.getIncomeCategories();

      if (_expenseCategories.isEmpty) {
        await _seedCategories(db);
        _expenseCategories = await db.getExpenseCategories();
        _incomeCategories = await db.getIncomeCategories();
      }

      _expenses = [
        ...await db.getExpenses(),
        ...await db.getArchivedExpenses(),
      ];
      _incomes = [
        ...await db.getIncomes(),
        ...await db.getArchivedIncomes(),
      ];

      if (_expenses.isEmpty && _incomes.isEmpty) {
        // fresh install — no seeding needed
      }
    } catch (_) {
      if (_expenseCategories.isEmpty) {
        _expenseCategories = defaultExpenseCategories;
        _incomeCategories = defaultIncomeCategories;
      }
    }

    notifyListeners();
  }

  Future<void> _seedCategories(DatabaseHelper db) async {
    for (final cat in defaultExpenseCategories) {
      await db.insertExpenseCategory(cat);
    }
    for (final cat in defaultIncomeCategories) {
      await db.insertIncomeCategory(cat);
    }
  }

  Future<void> seedLargeData() async {
    final rng = Random(42);
    final now = DateTime.now();

    final expenseNotes = [
      'Grocery shopping', 'Uber ride', 'Netflix subscription', 'Electric bill',
      'Lunch with team', 'Gas station', 'Amazon order', 'Gym membership',
      'Coffee & pastry', 'Phone bill', 'Internet bill', 'Movie tickets',
      'Pizza delivery', 'New sneakers', 'Doctor visit', 'Prescription',
      'Online course', 'Sushi dinner', 'Bus pass', 'Spotify premium',
      'Parking fee', 'House cleaning', 'Laundry', 'Office supplies',
      'Birthday gift', 'Book purchase', 'Streaming service', 'Water bill',
      'Dental checkup', 'Car wash', 'Taxi', 'Concert tickets',
      'Bakery', 'Fast food', 'Hardware tools', 'Plant pot',
      'Yoga class', 'Haircut', 'Pet food', 'Charity donation',
    ];

    final incomeNotes = [
      'Monthly salary', 'Freelance project', 'Dividend payment',
      'Birthday gift from mom', 'Tax refund', 'Bonus payment',
      'Side gig', 'Consulting fee', 'Interest earned', 'Rental income',
      'Cashback reward', 'Referral bonus', 'Stock sale', 'Commission',
    ];

    for (int i = 0; i < 200; i++) {
      final isExpense = i < 160;
      final daysAgo = rng.nextInt(90);
      final hours = rng.nextInt(12) + 8;
      final minutes = rng.nextInt(60);
      final date = now.subtract(Duration(days: daysAgo, hours: hours, minutes: minutes));

      if (isExpense) {
        final price = double.parse((rng.nextDouble() * 200 + 1).toStringAsFixed(2));
        final note = expenseNotes[rng.nextInt(expenseNotes.length)];
        final catIds = [rng.nextInt(8) + 1];
        if (rng.nextBool()) catIds.add(rng.nextInt(8) + 1);

        await addExpense(Expense(
          price: price,
          note: note,
          categoryIds: catIds.toSet().toList(),
          createdAt: date,
        ));
      } else {
        final price = double.parse((rng.nextDouble() * 5000 + 100).toStringAsFixed(2));
        final note = incomeNotes[rng.nextInt(incomeNotes.length)];
        final catIds = [rng.nextInt(5) + 1];

        await addIncome(Income(
          price: price,
          note: note,
          categoryIds: catIds,
          createdAt: date,
        ));
      }
    }
  }

  int _nextExpenseId = 1000;
  int _nextIncomeId = 1000;

  Future<void> addExpense(Expense expense) async {
    final e = expense.id != null
        ? expense
        : expense.copyWith(
            id: _nextExpenseId++,
            createdAt: expense.createdAt ?? DateTime.now(),
            updatedAt: expense.updatedAt ?? DateTime.now(),
          );
    _expenses.insert(0, e);
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.insertExpense(e);
    } catch (_) {}
  }

  Future<void> addIncome(Income income) async {
    final inc = income.id != null
        ? income
        : income.copyWith(
            id: _nextIncomeId++,
            createdAt: income.createdAt ?? DateTime.now(),
            updatedAt: income.updatedAt ?? DateTime.now(),
          );
    _incomes.insert(0, inc);
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.insertIncome(inc);
    } catch (_) {}
  }

  Future<void> deleteExpense(int id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _expenses[index] = _expenses[index].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.softDeleteExpense(id);
    } catch (_) {}
  }

  Future<void> deleteIncome(int id) async {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _incomes[index] = _incomes[index].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.softDeleteIncome(id);
    } catch (_) {}
  }

  Future<void> restoreExpense(int id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _expenses[index] = _expenses[index].copyWith(
      deletedAt: null,
      updatedAt: now,
    );
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.restoreExpense(id);
    } catch (_) {}
  }

  Future<void> restoreIncome(int id) async {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _incomes[index] = _incomes[index].copyWith(
      deletedAt: null,
      updatedAt: now,
    );
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.restoreIncome(id);
    } catch (_) {}
  }

  Future<void> permanentDeleteExpense(int id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.permanentDeleteExpense(id);
    } catch (_) {}
  }

  Future<void> permanentDeleteIncome(int id) async {
    _incomes.removeWhere((i) => i.id == id);
    notifyListeners();

    try {
      final db = DatabaseHelper();
      await db.permanentDeleteIncome(id);
    } catch (_) {}
  }

  int _nextExpenseCategoryId = 100;
  int _nextIncomeCategoryId = 100;

  void addExpenseCategory(ExpenseCategory category) {
    final cat = category.id != null
        ? category
        : category.copyWith(
            id: _nextExpenseCategoryId++,
            createdAt: category.createdAt ?? DateTime.now(),
            updatedAt: category.updatedAt ?? DateTime.now(),
          );
    _expenseCategories.add(cat);
    notifyListeners();

    try {
      DatabaseHelper().insertExpenseCategory(cat);
    } catch (_) {}
  }

  void addIncomeCategory(IncomeCategory category) {
    final cat = category.id != null
        ? category
        : category.copyWith(
            id: _nextIncomeCategoryId++,
            createdAt: category.createdAt ?? DateTime.now(),
            updatedAt: category.updatedAt ?? DateTime.now(),
          );
    _incomeCategories.add(cat);
    notifyListeners();

    try {
      DatabaseHelper().insertIncomeCategory(cat);
    } catch (_) {}
  }
}

final List<ExpenseCategory> defaultExpenseCategories = [
  ExpenseCategory(id: 1, name: 'Food', emoji: '🍕'),
  ExpenseCategory(id: 2, name: 'Transport', emoji: '🚗'),
  ExpenseCategory(id: 3, name: 'Shopping', emoji: '🛍️'),
  ExpenseCategory(id: 4, name: 'Bills', emoji: '📄'),
  ExpenseCategory(id: 5, name: 'Entertainment', emoji: '🎬'),
  ExpenseCategory(id: 6, name: 'Health', emoji: '💊'),
  ExpenseCategory(id: 7, name: 'Education', emoji: '📚'),
  ExpenseCategory(id: 8, name: 'Housing', emoji: '🏠'),
  ExpenseCategory(id: 9, name: 'Other', emoji: '📦'),
];

final List<IncomeCategory> defaultIncomeCategories = [
  IncomeCategory(id: 1, name: 'Salary', emoji: '💰'),
  IncomeCategory(id: 2, name: 'Freelance', emoji: '💻'),
  IncomeCategory(id: 3, name: 'Investment', emoji: '📈'),
  IncomeCategory(id: 4, name: 'Gift', emoji: '🎁'),
  IncomeCategory(id: 5, name: 'Refund', emoji: '↩️'),
  IncomeCategory(id: 6, name: 'Other', emoji: '📦'),
];
