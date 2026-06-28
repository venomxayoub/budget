import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class EntryDetailScreen extends StatelessWidget {
  final EntryItem entry;

  const EntryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<TransactionProvider>();
    final accentColor = entry.isExpense ? Colors.redAccent : Colors.green;

    final catMap = provider.getCategoryMap(entry.isExpense);

    final categories =
        entry.categoryIds
            .map((id) => catMap[id])
            .where((c) => c != null)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.isExpense ? 'Expense' : 'Income'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${entry.isExpense ? '-' : '+'}${formatCurrency(entry.amountCents)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (entry.note.isNotEmpty) ...[
              Text(
                'Note',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(entry.note, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
            ],
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  categories
                      .map(
                        (cat) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${cat.emoji}  ${cat.name}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy - h:mm a').format(entry.createdAt),
              style: const TextStyle(fontSize: 14),
            ),
            if (entry.deletedAt != null) ...[
              Text(
                'Deleted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat(
                  'EEEE, MMMM d, yyyy - h:mm a',
                ).format(entry.deletedAt!),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 32),
            if (entry.isArchived) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _mutateEntry(context, EntryAction.restore),
                  icon: const Icon(Icons.restore, color: Colors.blue),
                  label: const Text(
                    'Restore',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      () => _mutateEntry(context, EntryAction.permanentDelete),
                  icon: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Delete Forever',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _mutateEntry(context, EntryAction.archive),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _mutateEntry(BuildContext context, EntryAction action) async {
    final provider = context.read<TransactionProvider>();
    try {
      if (entry.isExpense) {
        switch (action) {
          case EntryAction.archive:
            await provider.deleteExpense(entry.id);
          case EntryAction.restore:
            await provider.restoreExpense(entry.id);
          case EntryAction.permanentDelete:
            await provider.permanentDeleteExpense(entry.id);
        }
      } else {
        switch (action) {
          case EntryAction.archive:
            await provider.deleteIncome(entry.id);
          case EntryAction.restore:
            await provider.restoreIncome(entry.id);
          case EntryAction.permanentDelete:
            await provider.permanentDeleteIncome(entry.id);
        }
      }
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update entry: $error')));
    }
  }
}

enum EntryAction { archive, restore, permanentDelete }
