import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class EntryTile extends StatelessWidget {
  final EntryItem entry;
  final Map<int, dynamic> categoryMap;
  final bool isOdd;
  final VoidCallback onTap;

  const EntryTile({
    super.key,
    required this.entry,
    required this.categoryMap,
    required this.isOdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = entry.isExpense ? Colors.redAccent : Colors.green;
    final accentContainer =
        entry.isExpense ? Colors.red.shade50 : Colors.green.shade50;
    final isDark = theme.brightness == Brightness.dark;
    final rowColor =
        isOdd
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.42)
            : colorScheme.surface;
    final categoryPills =
        entry.categoryIds
            .map((id) => categoryMap[id])
            .where((cat) => cat != null)
            .map(
              (cat) => _CategoryPill(
                emoji: cat.emoji as String,
                name: cat.name as String,
              ),
            )
            .toList();

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? accentColor.withValues(alpha: 0.18)
                          : accentContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  entry.isExpense
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.note.isEmpty
                          ? (entry.isExpense ? 'Expense' : 'Income')
                          : entry.note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (categoryPills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 5, children: categoryPills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${entry.isExpense ? '-' : '+'}'
                        '${formatCurrency(entry.amountCents)}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String emoji;
  final String name;

  const _CategoryPill({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
