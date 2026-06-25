import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../widgets/entry_tile.dart';
import '../widgets/sidebar.dart';
import 'entry_form_screen.dart';
import 'entry_detail_screen.dart';
import 'categories_screen.dart';
import 'category_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activePage = 'entries';

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Sidebar(
        activePage: _activePage,
        onPageChanged: (page) {
          setState(() => _activePage = page);
          Navigator.pop(context);
        },
      ),
      body: Stack(
        children: [
          _activePage == 'entries'
              ? _buildEntriesView()
              : CategoriesScreen(
                  onAddExpenseCategory: () => _openCategoryForm(context, true),
                  onAddIncomeCategory: () => _openCategoryForm(context, false),
                ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _activePage == 'entries'
          ? Column(
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
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'expense_cat_fab',
                  mini: true,
                  backgroundColor: Colors.redAccent,
                  onPressed: () => _openCategoryForm(context, true),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'income_cat_fab',
                  mini: true,
                  backgroundColor: Colors.green,
                  onPressed: () => _openCategoryForm(context, false),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
    );
  }

  void _openEntryForm(BuildContext context, bool isExpense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(isExpense: isExpense),
      ),
    );
  }

  void _openCategoryForm(BuildContext context, bool isExpense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(isExpense: isExpense),
      ),
    );
  }

  Widget _buildEntriesView() {
    final provider = context.watch<TransactionProvider>();
    final entries = provider.entries;
    final expenseCatMap = provider.expenseCategoryMap;
    final incomeCatMap = provider.incomeCategoryMap;

    final groupedEntries = <String, List<EntryItem>>{};
    for (final entry in entries) {
      final key = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    final sortedDays = groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add an expense or income',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
        final isYesterday =
            _isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

    double totalExpense = 0;
    double totalIncome = 0;
    for (final e in entries) {
      if (e.isExpense) {
        totalExpense += e.price;
      } else {
        totalIncome += e.price;
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
                '+\$${totalIncome.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          if (totalExpense > 0)
            Text(
              '-\$${totalExpense.toStringAsFixed(0)}',
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
