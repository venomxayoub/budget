import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../database/database_helper.dart';
import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../utils/currency.dart';
import '../widgets/entry_tile.dart';
import '../widgets/sidebar.dart';
import 'entry_form_screen.dart';
import 'entry_detail_screen.dart';
import 'categories_screen.dart';
import 'category_form_screen.dart';
import 'debt_profiles_screen.dart';
import 'archived_debt_profiles_screen.dart';
import 'subscriptions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _drawerSwipeWidth = 96.0;

  String _activePage = 'entries';
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(
        context.read<TransactionProvider>().processSubscriptionsIfNeeded(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          drawerEnableOpenDragGesture: true,
          // Android's system back gesture owns the very edge of the display.
          // Keep the drawer drag target wide enough to start just inside it.
          drawerEdgeDragWidth: _drawerSwipeWidth,
          drawer: Sidebar(
            activePage: _activePage,
            onPageChanged: (page) {
              setState(() => _activePage = page);
              Navigator.pop(context);
            },
            onImportDatabase: () async {
              Navigator.pop(context);
              await _importPreviousData();
            },
          ),
          body: _buildActivePage(),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  Widget _buildActivePage() => switch (_activePage) {
    'categories' => CategoriesScreen(
      onEditExpenseCategory:
          (category) => _openExpenseCategoryForm(context, category),
      onEditIncomeCategory:
          (category) => _openIncomeCategoryForm(context, category),
    ),
    'debts' => const DebtProfilesScreen(),
    'subscriptions' => const SubscriptionsScreen(),
    'archive_entries' => _buildArchiveView(),
    'archive_debt_profiles' => const ArchivedDebtProfilesScreen(),
    _ => _buildEntriesView(),
  };

  Widget? _buildFloatingActionButton() {
    if (_activePage == 'entries') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'expense_fab',
            mini: true,
            backgroundColor: Colors.redAccent,
            onPressed: () => _openEntryForm(context, true),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'income_fab',
            mini: true,
            backgroundColor: Colors.green,
            onPressed: () => _openEntryForm(context, false),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      );
    }
    if (_activePage != 'categories') return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'expense_cat_fab',
          mini: true,
          backgroundColor: Colors.redAccent,
          onPressed: () => _openExpenseCategoryForm(context),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'income_cat_fab',
          mini: true,
          backgroundColor: Colors.green,
          onPressed: () => _openIncomeCategoryForm(context),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _importPreviousData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['db'],
        withData: true,
      );
      if (result == null || !mounted) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw StateError('The selected database could not be read.');
      }

      await DatabaseHelper().importDatabase(bytes);
      if (!mounted) return;
      await context.read<TransactionProvider>().loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Previous data imported successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not import data: $error')));
    }
  }

  void _openEntryForm(BuildContext context, bool isExpense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EntryFormScreen(isExpense: isExpense)),
    );
  }

  void _openExpenseCategoryForm(
    BuildContext context, [
    ExpenseCategory? category,
  ]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                CategoryFormScreen(isExpense: true, expenseCategory: category),
      ),
    );
  }

  void _openIncomeCategoryForm(
    BuildContext context, [
    IncomeCategory? category,
  ]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                CategoryFormScreen(isExpense: false, incomeCategory: category),
      ),
    );
  }

  Widget _buildEntriesView() {
    final provider = context.watch<TransactionProvider>();
    final allEntries = provider.entries;
    final expenseCatMap = provider.expenseCategoryMap;
    final incomeCatMap = provider.incomeCategoryMap;

    final monthEntries =
        allEntries.where((e) {
          return e.createdAt.year == _selectedMonth.year &&
              e.createdAt.month == _selectedMonth.month;
        }).toList();

    final groupedEntries = <String, List<EntryItem>>{};
    for (final entry in monthEntries) {
      final key = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    final sortedDays =
        groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        _MonthHeader(
          selectedMonth: _selectedMonth,
          isCurrentMonth: _isCurrentMonth,
          entries: monthEntries,
          onPreviousMonth: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
                1,
              );
            });
          },
          onNextMonth: () {
            if (!_isCurrentMonth) {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                  1,
                );
              });
            }
          },
        ),
        Expanded(
          child:
              allEntries.isEmpty
                  ? _emptyState(
                    'No entries yet',
                    'Tap + to add an expense or income',
                  )
                  : monthEntries.isEmpty
                  ? _emptyState(
                    'No entries in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                    'Switch to a different month or add new entries',
                  )
                  : ListView.builder(
                    itemCount: sortedDays.length,
                    itemBuilder: (context, dayIndex) {
                      final day = sortedDays[dayIndex];
                      final dayEntries = groupedEntries[day]!;
                      final date = DateTime.parse(day);
                      final isToday = _isSameDay(date, DateTime.now());
                      final isYesterday = _isSameDay(
                        date,
                        DateTime.now().subtract(const Duration(days: 1)),
                      );

                      String dayLabel;
                      if (isToday) {
                        dayLabel = 'Today';
                      } else if (isYesterday) {
                        dayLabel = 'Yesterday';
                      } else {
                        dayLabel = DateFormat('EEEE, MMM d').format(date);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DayStatusBar(
                            dayLabel: dayLabel,
                            date: date,
                            entries: dayEntries,
                          ),
                          ...List.generate(dayEntries.length, (i) {
                            final entry = dayEntries[i];
                            final catMap =
                                entry.isExpense ? expenseCatMap : incomeCatMap;

                            return EntryTile(
                              entry: entry,
                              categoryMap: catMap,
                              isOdd: i.isOdd,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => EntryDetailScreen(entry: entry),
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildArchiveView() {
    final provider = context.watch<TransactionProvider>();
    final entries = provider.archivedEntries;
    final expenseCatMap = provider.expenseCategoryMap;
    final incomeCatMap = provider.incomeCategoryMap;

    final groupedEntries = <String, List<EntryItem>>{};
    for (final entry in entries) {
      final key = DateFormat('yyyy-MM-dd').format(entry.deletedAt!);
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    final sortedDays =
        groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No archived entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: sortedDays.length,
      itemBuilder: (context, dayIndex) {
        final day = sortedDays[dayIndex];
        final dayEntries = groupedEntries[day]!;
        final date = DateTime.parse(day);
        final isToday = _isSameDay(date, DateTime.now());
        final isYesterday = _isSameDay(
          date,
          DateTime.now().subtract(const Duration(days: 1)),
        );

        String dayLabel;
        if (isToday) {
          dayLabel = 'Today';
        } else if (isYesterday) {
          dayLabel = 'Yesterday';
        } else {
          dayLabel = DateFormat('EEEE, MMM d').format(date);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayStatusBar(dayLabel: dayLabel, date: date, entries: dayEntries),
            ...List.generate(dayEntries.length, (i) {
              final entry = dayEntries[i];
              final catMap = entry.isExpense ? expenseCatMap : incomeCatMap;

              return EntryTile(
                entry: entry,
                categoryMap: catMap,
                isOdd: i.isOdd,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryDetailScreen(entry: entry),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final List<EntryItem> entries;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _MonthHeader({
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.entries,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    var totalExpense = 0;
    var totalIncome = 0;
    for (final e in entries) {
      if (e.isExpense) {
        totalExpense += e.amountCents;
      } else {
        totalIncome += e.amountCents;
      }
    }

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousMonth,
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(selectedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : onNextMonth,
            style: IconButton.styleFrom(
              disabledForegroundColor: Colors.transparent,
            ),
          ),
          const Spacer(),
          if (totalIncome > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '+${formatCurrency(totalIncome)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          if (totalExpense > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '-${formatCurrency(totalExpense)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayStatusBar extends StatelessWidget {
  final String dayLabel;
  final DateTime date;
  final List<EntryItem> entries;

  const _DayStatusBar({
    required this.dayLabel,
    required this.date,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    var totalExpense = 0;
    var totalIncome = 0;
    for (final e in entries) {
      if (e.isExpense) {
        totalExpense += e.amountCents;
      } else {
        totalIncome += e.amountCents;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (totalIncome > 0)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '+${formatCurrency(totalIncome)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          if (totalExpense > 0)
            Text(
              '-${formatCurrency(totalExpense)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
    );
  }
}
