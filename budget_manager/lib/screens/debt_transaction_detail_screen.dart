import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class DebtTransactionDetailScreen extends StatelessWidget {
  final int transactionId;

  const DebtTransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transaction = provider.getDebtTransactionById(transactionId);
    if (transaction == null) {
      return const Scaffold(body: Center(child: Text('Transaction not found')));
    }

    final color = switch (transaction.type) {
      DebtTransactionType.gave => Colors.blue,
      DebtTransactionType.received => Colors.red,
      DebtTransactionType.update => Colors.green,
    };
    final amount = switch (transaction.type) {
      DebtTransactionType.gave => '+${formatCurrency(transaction.amountCents)}',
      DebtTransactionType.received =>
        '-${formatCurrency(transaction.amountCents)}',
      DebtTransactionType.update =>
        '${formatSignedCurrency(provider.balanceBeforeDebtTransaction(transaction))} → ${formatSignedCurrency(transaction.amountCents)}',
    };

    return Scaffold(
      appBar: AppBar(title: Text(transaction.type.label)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              amount,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize:
                    transaction.type == DebtTransactionType.update ? 25 : 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (transaction.note?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            Text('Note', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(transaction.note!),
          ],
          const SizedBox(height: 24),
          Text('Date', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            DateFormat(
              'EEEE, MMMM d, yyyy - h:mm a',
            ).format(transaction.createdAt!),
          ),
          const SizedBox(height: 36),
          OutlinedButton.icon(
            key: const Key('delete-debt-transaction'),
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Transaction'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Transaction?'),
            content: const Text(
              'This transaction will be removed from the ledger balance.',
            ),
            actions: [
              TextButton(
                key: const Key('cancel-delete-debt-transaction'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-delete-debt-transaction'),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<TransactionProvider>().deleteDebtTransaction(
      transactionId,
    );
    if (context.mounted) Navigator.pop(context);
  }
}
