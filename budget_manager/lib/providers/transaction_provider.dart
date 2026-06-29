import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../models/debt_profile.dart';
import '../models/debt_transaction.dart';
import '../models/subscription.dart';
import '../models/subscription_status_event.dart';
import '../database/database_helper.dart';

class EntryItem {
  final int id;
  final bool isExpense;
  final int amountCents;
  final String note;
  final List<int> categoryIds;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final int? subscriptionId;
  final DateTime? subscriptionScheduledDate;

  EntryItem({
    required this.id,
    required this.isExpense,
    required this.amountCents,
    required this.note,
    required this.categoryIds,
    required this.createdAt,
    this.deletedAt,
    this.subscriptionId,
    this.subscriptionScheduledDate,
  });

  bool get isArchived => deletedAt != null;
}

class TransactionProvider extends ChangeNotifier {
  TransactionProvider({
    DatabaseHelper? databaseHelper,
    DateTime Function()? clock,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper(),
       _clock = clock ?? DateTime.now;

  final DatabaseHelper _databaseHelper;
  final DateTime Function() _clock;
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  List<ExpenseCategory> _expenseCategories = [];
  List<IncomeCategory> _incomeCategories = [];
  List<DebtProfile> _debtProfiles = [];
  List<DebtTransaction> _debtTransactions = [];
  List<Subscription> _subscriptions = [];
  List<SubscriptionStatusEvent> _subscriptionStatusEvents = [];
  bool _isProcessingSubscriptions = false;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Income> get incomes => List.unmodifiable(_incomes);
  List<ExpenseCategory> get expenseCategories =>
      List.unmodifiable(_expenseCategories);
  List<IncomeCategory> get incomeCategories =>
      List.unmodifiable(_incomeCategories);
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  List<DebtProfile> get debtProfiles {
    final profiles =
        _debtProfiles.where((profile) => !profile.isArchived).toList()..sort(
          (a, b) => _latestDebtActivity(b).compareTo(_latestDebtActivity(a)),
        );
    return List.unmodifiable(profiles);
  }

  List<DebtProfile> get archivedDebtProfiles {
    final profiles =
        _debtProfiles.where((profile) => profile.isArchived).toList()
          ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return List.unmodifiable(profiles);
  }

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
            subscriptionId: e.subscriptionId,
            subscriptionScheduledDate: e.subscriptionScheduledDate,
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
            subscriptionId: e.subscriptionId,
            subscriptionScheduledDate: e.subscriptionScheduledDate,
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
          subscriptionId: item.subscriptionId,
          subscriptionScheduledDate: item.subscriptionScheduledDate,
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

  DebtProfile? getDebtProfileById(int id) {
    for (final profile in _debtProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Subscription? getSubscriptionById(int id) {
    for (final subscription in _subscriptions) {
      if (subscription.id == id) return subscription;
    }
    return null;
  }

  List<Expense> subscriptionPayments(int subscriptionId) {
    final payments =
        _expenses
            .where(
              (expense) =>
                  expense.subscriptionId == subscriptionId &&
                  expense.deletedAt == null,
            )
            .toList()
          ..sort((a, b) {
            final byDate = (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            );
            if (byDate != 0) return byDate;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });
    return List.unmodifiable(payments);
  }

  List<SubscriptionStatusEvent> subscriptionStatusEvents(int subscriptionId) {
    final events =
        _subscriptionStatusEvents
            .where((event) => event.subscriptionId == subscriptionId)
            .toList()
          ..sort((a, b) {
            final byDate = b.occurredAt.compareTo(a.occurredAt);
            if (byDate != 0) return byDate;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });
    return List.unmodifiable(events);
  }

  DebtTransaction? getDebtTransactionById(int id) {
    for (final transaction in _debtTransactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  List<DebtTransaction> debtTransactionsForProfile(int profileId) {
    final transactions =
        _debtTransactions
            .where((transaction) => transaction.profileId == profileId)
            .toList()
          ..sort(_compareDebtTransactionsNewestFirst);
    return List.unmodifiable(transactions);
  }

  int debtBalanceForProfile(int profileId) {
    final profile = getDebtProfileById(profileId);
    if (profile == null) {
      throw StateError('The debt profile no longer exists.');
    }

    var balance = profile.initialBalanceCents;
    final transactions =
        _debtTransactions
            .where((transaction) => transaction.profileId == profileId)
            .toList()
          ..sort(_compareDebtTransactionsChronologically);
    for (final transaction in transactions) {
      balance = _applyDebtTransaction(balance, transaction);
    }
    return balance;
  }

  int balanceBeforeDebtTransaction(DebtTransaction target) {
    final profile = getDebtProfileById(target.profileId);
    if (profile == null) {
      throw StateError('The debt profile no longer exists.');
    }

    var balance = profile.initialBalanceCents;
    final transactions =
        _debtTransactions
            .where((transaction) => transaction.profileId == target.profileId)
            .toList()
          ..sort(_compareDebtTransactionsChronologically);
    for (final transaction in transactions) {
      if (transaction.id == target.id) return balance;
      balance = _applyDebtTransaction(balance, transaction);
    }
    throw StateError('The debt transaction no longer exists.');
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

      await _databaseHelper.processSubscriptionsIfNeeded(_clock());
      _expenseCategories = await _databaseHelper.getExpenseCategories();

      _expenses = [
        ...await _databaseHelper.getExpenses(),
        ...await _databaseHelper.getArchivedExpenses(),
      ];
      _incomes = [
        ...await _databaseHelper.getIncomes(),
        ...await _databaseHelper.getArchivedIncomes(),
      ];
      _debtProfiles = [
        ...await _databaseHelper.getDebtProfiles(),
        ...await _databaseHelper.getArchivedDebtProfiles(),
      ];
      _debtTransactions = await _databaseHelper.getDebtTransactions();
      _subscriptions = await _databaseHelper.getSubscriptions();
      _subscriptionStatusEvents =
          await _databaseHelper.getSubscriptionStatusEvents();
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

  Future<void> createSubscription({
    required String name,
    required int priceCents,
    required SubscriptionPeriod period,
    required DateTime firstRenewalDate,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('A subscription name is required.');
    }
    if (priceCents <= 0) {
      throw ArgumentError('Subscription price must be positive.');
    }
    final now = _clock();
    final today = _dateOnly(now);
    final firstRenewal = _dateOnly(firstRenewalDate);
    if (firstRenewal.isBefore(today)) {
      throw ArgumentError('The first renewal date cannot be in the past.');
    }
    await _databaseHelper.createSubscription(
      subscription: Subscription(
        name: trimmedName,
        priceCents: priceCents,
        period: period,
        status: SubscriptionStatus.active,
        renewalAnchorDate: firstRenewal,
        nextRenewalDate: firstRenewal,
        createdAt: now,
        updatedAt: now,
      ),
      today: today,
    );
    await _refreshSubscriptionData();
  }

  Future<void> updateSubscription({
    required int id,
    required String name,
    required int priceCents,
    required SubscriptionPeriod period,
    required DateTime nextRenewalDate,
  }) async {
    final existing = getSubscriptionById(id);
    if (existing == null) {
      throw StateError('The subscription no longer exists.');
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('A subscription name is required.');
    }
    if (priceCents <= 0) {
      throw ArgumentError('Subscription price must be positive.');
    }
    final nextRenewal = _dateOnly(nextRenewalDate);
    final updated = existing.copyWith(
      name: trimmedName,
      priceCents: priceCents,
      period: period,
      renewalAnchorDate: nextRenewal,
      nextRenewalDate: nextRenewal,
      updatedAt: _clock(),
    );
    _requireUpdated(await _databaseHelper.updateSubscription(updated));
    await _refreshSubscriptionData();
  }

  Future<void> pauseSubscription(int id) => _setSubscriptionStatus(
    id,
    SubscriptionStatus.paused,
    chargeImmediately: false,
  );

  Future<void> cancelSubscription(int id) => _setSubscriptionStatus(
    id,
    SubscriptionStatus.cancelled,
    chargeImmediately: false,
  );

  Future<void> reactivateSubscription(int id) => _setSubscriptionStatus(
    id,
    SubscriptionStatus.active,
    chargeImmediately: true,
  );

  Future<void> _setSubscriptionStatus(
    int id,
    SubscriptionStatus status, {
    required bool chargeImmediately,
  }) async {
    final existing = getSubscriptionById(id);
    if (existing == null) {
      throw StateError('The subscription no longer exists.');
    }
    if (chargeImmediately && existing.status == SubscriptionStatus.active) {
      throw StateError('The subscription is already active.');
    }
    await _databaseHelper.changeSubscriptionStatus(
      id: id,
      status: status,
      now: _clock(),
      chargeImmediately: chargeImmediately,
    );
    await _refreshSubscriptionData();
  }

  Future<void> processSubscriptionsIfNeeded() async {
    if (_isProcessingSubscriptions) return;
    _isProcessingSubscriptions = true;
    try {
      final processed = await _databaseHelper.processSubscriptionsIfNeeded(
        _clock(),
      );
      if (processed) await _refreshSubscriptionData();
    } finally {
      _isProcessingSubscriptions = false;
    }
  }

  Future<void> _refreshSubscriptionData() async {
    _expenseCategories = await _databaseHelper.getExpenseCategories();
    _expenses = [
      ...await _databaseHelper.getExpenses(),
      ...await _databaseHelper.getArchivedExpenses(),
    ];
    _subscriptions = await _databaseHelper.getSubscriptions();
    _subscriptionStatusEvents =
        await _databaseHelper.getSubscriptionStatusEvents();
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

  Future<void> createDebtProfile({
    required String name,
    required int initialBalanceCents,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('A profile name is required.');

    final now = DateTime.now();
    final pending = DebtProfile(
      name: trimmedName,
      initialBalanceCents: initialBalanceCents,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _databaseHelper.insertDebtProfile(pending);
    _debtProfiles.add(pending.copyWith(id: id));
    notifyListeners();
  }

  Future<void> renameDebtProfile(int id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('A profile name is required.');
    final index = _debtProfiles.indexWhere((profile) => profile.id == id);
    if (index == -1 || _debtProfiles[index].isArchived) {
      throw StateError('The debt profile no longer exists.');
    }

    _requireUpdated(await _databaseHelper.renameDebtProfile(id, trimmedName));
    _debtProfiles[index] = _debtProfiles[index].copyWith(
      name: trimmedName,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> deleteDebtProfile(int id) async {
    final index = _debtProfiles.indexWhere((profile) => profile.id == id);
    if (index == -1 || _debtProfiles[index].isArchived) return;

    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.softDeleteDebtProfile(id));
    _debtProfiles[index] = _debtProfiles[index].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> restoreDebtProfile(int id) async {
    final index = _debtProfiles.indexWhere((profile) => profile.id == id);
    if (index == -1 || !_debtProfiles[index].isArchived) return;

    final now = DateTime.now();
    _requireUpdated(await _databaseHelper.restoreDebtProfile(id));
    _debtProfiles[index] = _debtProfiles[index].copyWith(
      deletedAt: null,
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> addDebtTransaction({
    required int profileId,
    required DebtTransactionType type,
    required int amountCents,
    String? note,
  }) async {
    if (type != DebtTransactionType.update && amountCents <= 0) {
      throw ArgumentError('Transaction amounts must be positive.');
    }
    final profileIndex = _debtProfiles.indexWhere(
      (profile) => profile.id == profileId && !profile.isArchived,
    );
    if (profileIndex == -1) {
      throw StateError('The debt profile no longer exists.');
    }

    final now = DateTime.now();
    final trimmedNote = note?.trim();
    final pending = DebtTransaction(
      profileId: profileId,
      type: type,
      amountCents: amountCents,
      note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _databaseHelper.insertDebtTransaction(pending);
    _debtTransactions.add(pending.copyWith(id: id));
    _debtProfiles[profileIndex] = _debtProfiles[profileIndex].copyWith(
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> deleteDebtTransaction(int id) async {
    final transactionIndex = _debtTransactions.indexWhere(
      (transaction) => transaction.id == id,
    );
    if (transactionIndex == -1) return;

    final profileId = _debtTransactions[transactionIndex].profileId;
    _requireUpdated(await _databaseHelper.softDeleteDebtTransaction(id));
    _debtTransactions.removeAt(transactionIndex);
    final profileIndex = _debtProfiles.indexWhere(
      (profile) => profile.id == profileId,
    );
    if (profileIndex != -1) {
      _debtProfiles[profileIndex] = _debtProfiles[profileIndex].copyWith(
        updatedAt: DateTime.now(),
      );
    }
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

  DateTime _latestDebtActivity(DebtProfile profile) {
    var latest = profile.updatedAt ?? profile.createdAt ?? DateTime(0);
    for (final transaction in _debtTransactions) {
      if (transaction.profileId != profile.id) continue;
      final createdAt = transaction.createdAt ?? DateTime(0);
      if (createdAt.isAfter(latest)) latest = createdAt;
    }
    return latest;
  }

  static int _applyDebtTransaction(int balance, DebtTransaction transaction) =>
      switch (transaction.type) {
        DebtTransactionType.gave => balance + transaction.amountCents,
        DebtTransactionType.received => balance - transaction.amountCents,
        DebtTransactionType.update => transaction.amountCents,
      };

  static int _compareDebtTransactionsChronologically(
    DebtTransaction a,
    DebtTransaction b,
  ) {
    final byDate = (a.createdAt ?? DateTime(0)).compareTo(
      b.createdAt ?? DateTime(0),
    );
    if (byDate != 0) return byDate;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  static int _compareDebtTransactionsNewestFirst(
    DebtTransaction a,
    DebtTransaction b,
  ) => -_compareDebtTransactionsChronologically(a, b);
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

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
