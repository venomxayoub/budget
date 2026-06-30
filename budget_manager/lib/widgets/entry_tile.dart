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
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = entry.isExpense ? Colors.redAccent : Colors.green;

    return Material(
      color:
          isOdd
              ? colorScheme.surfaceContainerLow.withValues(alpha: 0.3)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: borderColor, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.note,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          entry.categoryIds.map((id) {
                            final cat = categoryMap[id];
                            if (cat == null) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${cat.emoji} ${cat.name}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.isExpense ? '-' : '+'}${formatCurrency(entry.amountCents)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: entry.isExpense ? Colors.redAccent : Colors.green,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(entry.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
