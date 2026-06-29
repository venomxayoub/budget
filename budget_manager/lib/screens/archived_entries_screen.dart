import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import '../widgets/entry_tile.dart';
import 'entry_detail_screen.dart';

class ArchivedEntriesScreen extends StatelessWidget {
  const ArchivedEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Archived Entries',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                entries.isEmpty
                    ? _EmptyArchive()
                    : ListView.builder(
                      itemCount: sortedDays.length,
                      itemBuilder: (context, dayIndex) {
                        final day = sortedDays[dayIndex];
                        final dayEntries = groupedEntries[day]!;
                        final date = DateTime.parse(day);
                        final now = DateTime.now();
                        final isToday = _isSameDay(date, now);
                        final isYesterday = _isSameDay(
                          date,
                          now.subtract(const Duration(days: 1)),
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
                              final catMap = entry.isExpense
                                  ? expenseCatMap
                                  : incomeCatMap;

                              return Row(
                                children: [
                                  Expanded(
                                    child: EntryTile(
                                      entry: entry,
                                      categoryMap: catMap,
                                      isOdd: i.isOdd,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EntryDetailScreen(entry: entry),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: IconButton(
                                      key: Key('restore-entry-${entry.id}'),
                                      icon: const Icon(Icons.restore),
                                      tooltip: 'Restore',
                                      onPressed: () => _restoreEntry(
                                        context,
                                        entry,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _restoreEntry(BuildContext context, EntryItem entry) async {
    final provider = context.read<TransactionProvider>();
    if (entry.isExpense) {
      await provider.restoreExpense(entry.id);
    } else {
      await provider.restoreIncome(entry.id);
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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

class _EmptyArchive extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}
