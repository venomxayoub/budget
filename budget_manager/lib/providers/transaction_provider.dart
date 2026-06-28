import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../database/database_helper.dart';

class EntryItem {
  final int id;
  final bool isExpense;
  final int amountCents;
  final String note;
  final List<int> categoryIds;
  final DateTime createdAt;
  final DateTime? deletedAt;

  EntryItem({
    required this.id,
    required this.isExpense,
    required this.amountCents,
    required this.note,
    required this.categoryIds,
    required this.createdAt,
    this.deletedAt,
  });

  bool get isArchived => deletedAt != null;
}

class TransactionProvider extends ChangeNotifier {
  TransactionProvider({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _databaseHelper;
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  List<ExpenseCategory> _expenseCategories = [];
  List<IncomeCategory> _incomeCategories = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Income> get incomes => List.unmodifiable(_incomes);
  List<ExpenseCategory> get expenseCategories =>
      List.unmodifiable(_expenseCategories);
  List<IncomeCategory> get incomeCategories =>
      List.unmodifiable(_incomeCategories);

  List<EntryItem> get entries {
    final items = <EntryItem>[
      for (final e in _expenses)
        if (e.deletedAt == null)
          EntryItem(
            id: e.id!,
            isExpense: true,
            amountCents: e.amountCents,
            note: e.note,
            categoryIds: e.categoryIds,
            createdAt: e.createdAt!,
          ),
      for (final i in _incomes)
        if (i.deletedAt == null)
          EntryItem(
            id: i.id!,
            isExpense: false,
            amountCents: i.amountCents,
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
            amountCents: e.amountCents,
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
            amountCents: i.amountCents,
            note: i.note,
            categoryIds: i.categoryIds,
            createdAt: i.createdAt!,
            deletedAt: i.deletedAt,
          ),
    ];
    items.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return items;
  }

  EntryItem? getEntryById({required int id, required bool isExpense}) {
    if (isExpense) {
      for (final item in _expenses) {
        if (item.id != id) continue;
        return EntryItem(
          id: item.id!,
          isExpense: true,
          amountCents: item.amountCents,
          note: item.note,
          categoryIds: item.categoryIds,
          createdAt: item.createdAt!,
          deletedAt: item.deletedAt,
        );
      }
    } else {
      for (final item in _incomes) {
        if (item.id != id) continue;
        return EntryItem(
          id: item.id!,
          isExpense: false,
          amountCents: item.amountCents,
          note: item.note,
          categoryIds: item.categoryIds,
          createdAt: item.createdAt!,
          deletedAt: item.deletedAt,
        );
      }
    }
    return null;
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

  Map<int, ExpenseCategory> get expenseCategoryMap => {
    for (final c in _expenseCategories)
      if (c.id != null) c.id!: c,
  };

  Map<int, IncomeCategory> get incomeCategoryMap => {
    for (final c in _incomeCategories)
      if (c.id != null) c.id!: c,
  };

  Map<int, dynamic> getCategoryMap(bool isExpense) =>
      isExpense ? expenseCategoryMap : incomeCategoryMap;

  List<dynamic> getCategoriesList(bool isExpense) =>
      (isExpense ? _expenseCategories : _incomeCategories)
          .map((c) => c as dynamic)
          .toList();

  Future<void> loadData() async {
    _expenseCategories = List.of(defaultExpenseCategories);
    _incomeCategories = List.of(defaultIncomeCategories);

    try {
      _expenseCategories = await _databaseHelper.getExpenseCategories();
      _incomeCategories = await _databaseHelper.getIncomeCategories();

      if (_expenseCategories.isEmpty || _incomeCategories.isEmpty) {
        await _seedMissingCategories();
        _expenseCategories = await _databaseHelper.getExpenseCategories();
        _incomeCategories = await _databaseHelper.getIncomeCategories();
      }

      _expenses = [
        ...await _databaseHelper.getExpenses(),
        ...await _databaseHelper.getArchivedExpenses(),
      ];
      _incomes = [
        ...await _databaseHelper.getIncomes(),
        ...await _databaseHelper.getArchivedIncomes(),
      ];
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'budget manager persistence',
          context: ErrorDescription('while loading saved budget data'),
        ),
      );
      if (_expenseCategories.isEmpty) {
        _expenseCategories = List.of(defaultExpenseCategories);
      }
      if (_incomeCategories.isEmpty) {
        _incomeCategories = List.of(defaultIncomeCategories);
      }
    }

    notifyListeners();
  }

  Future<void> _seedMissingCategories() async {
    if (_expenseCategories.isEmpty) {
      for (final cat in defaultExpenseCategories) {
        await _databaseHelper.insertExpenseCategory(cat);
      }
    }
    if (_incomeCategories.isEmpty) {
      for (final cat in defaultIncomeCategories) {
        await _databaseHelper.insertIncomeCategory(cat);
      }
    }
  }

  Future<void> addExpense(Expense expense) async {
    final now = DateTime.now();
    final pending = expense.copyWith(
      createdAt: expense.createdAt ?? now,
      updatedAt: expense.updatedAt ?? now,
    );
    final id = await _databaseHelper.insertExpense(pending);
    _expenses.insert(0, pending.copyWith(id: id));
    notifyListeners();
  }

  Future<void> addIncome(Income income) async {
    final now = DateTime.now();
    final pending = income.copyWith(
      createdAt: income.createdAt ?? now,
      updatedAt: income.updatedAt ?? now,
    );
    final id = await _databaseHelper.insertIncome(pending);
    _incomes.insert(0, pending.copyWith(id: id));
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index == -1) throw StateError('The saved expense no longer exists.');

    final updated = expense.copyWith(updatedAt: DateTime.now());
    _requireUpdated(await _databaseHelper.updateExpense(updated));
    _expenses[index] = updated;
    notifyListeners();
  }

  Future<void> updateIncome(Income income) async {
    final index = _incomes.indexWhere((item) => item.id == income.id);
    if (index == -1) throw StateError('The saved income no longer exists.');

    final updated = income.copyWith(updatedAt: DateTime.now());
    _requireUpdated(await _databaseHelper.updateIncome(updated));
    _incomes[index] = updated;
    notifyListeners();
  }

  Future<void> deleteExpense(int id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.softDeleteExpense(id));
    _expenses[index] = _expenses[index].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> deleteIncome(int id) async {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.softDeleteIncome(id));
    _incomes[index] = _incomes[index].copyWith(deletedAt: now, updatedAt: now);
    notifyListeners();
  }

  Future<void> restoreExpense(int id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.restoreExpense(id));
    _expenses[index] = _expenses[index].copyWith(
      deletedAt: null,
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> restoreIncome(int id) async {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.restoreIncome(id));
    _incomes[index] = _incomes[index].copyWith(deletedAt: null, updatedAt: now);
    notifyListeners();
  }

  Future<void> permanentDeleteExpense(int id) async {
    _requireUpdated(await _databaseHelper.permanentDeleteExpense(id));
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> permanentDeleteIncome(int id) async {
    _requireUpdated(await _databaseHelper.permanentDeleteIncome(id));
    _incomes.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<void> addExpenseCategory(ExpenseCategory category) async {
    final now = DateTime.now();
    final pending = category.copyWith(
      createdAt: category.createdAt ?? now,
      updatedAt: category.updatedAt ?? now,
    );
    final id = await _databaseHelper.insertExpenseCategory(pending);
    final cat = pending.copyWith(id: id);
    _expenseCategories.add(cat);
    _expenseCategories.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> addIncomeCategory(IncomeCategory category) async {
    final now = DateTime.now();
    final pending = category.copyWith(
      createdAt: category.createdAt ?? now,
      updatedAt: category.updatedAt ?? now,
    );
    final id = await _databaseHelper.insertIncomeCategory(pending);
    final cat = pending.copyWith(id: id);
    _incomeCategories.add(cat);
    _incomeCategories.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateExpenseCategory(ExpenseCategory category) async {
    final index = _expenseCategories.indexWhere(
      (item) => item.id == category.id,
    );
    if (index == -1) {
      throw StateError('The saved category no longer exists.');
    }

    final updated = category.copyWith(updatedAt: DateTime.now());
    _requireUpdated(await _databaseHelper.updateExpenseCategory(updated));
    _expenseCategories[index] = updated;
    _expenseCategories.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateIncomeCategory(IncomeCategory category) async {
    final index = _incomeCategories.indexWhere(
      (item) => item.id == category.id,
    );
    if (index == -1) {
      throw StateError('The saved category no longer exists.');
    }

    final updated = category.copyWith(updatedAt: DateTime.now());
    _requireUpdated(await _databaseHelper.updateIncomeCategory(updated));
    _incomeCategories[index] = updated;
    _incomeCategories.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _requireUpdated(int affectedRows) {
    if (affectedRows != 1) {
      throw StateError('The saved record no longer exists.');
    }
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
