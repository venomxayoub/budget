import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import '../utils/debt_display.dart';
import 'debt_transaction_detail_screen.dart';
import 'debt_transaction_form_screen.dart';

class DebtProfileDetailScreen extends StatelessWidget {
  final int profileId;

  const DebtProfileDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final profile = provider.getDebtProfileById(profileId);
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Profile not found')));
    }

    final balance = provider.debtBalanceForProfile(profileId);
    final balanceColor = debtBalanceColor(balance);
    final transactions = provider.debtTransactionsForProfile(profileId);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
        actions: [
          IconButton(
            key: const Key('rename-debt-profile'),
            tooltip: 'Rename',
            onPressed: () => _rename(context, profile.name),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: balanceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatSignedCurrency(balance),
                        key: const Key('debt-profile-current-balance'),
                        style: TextStyle(
                          color: balanceColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        debtBalanceLabel(balance),
                        style: TextStyle(color: balanceColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Initial balance: ${formatSignedCurrency(profile.initialBalanceCents)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            () => _openTransaction(
                              context,
                              DebtTransactionType.gave,
                            ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                        child: const Text('I Gave'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            () => _openTransaction(
                              context,
                              DebtTransactionType.received,
                            ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('I Received'),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const Key('manual-debt-balance-update'),
                    onPressed:
                        () => _openTransaction(
                          context,
                          DebtTransactionType.update,
                        ),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('Update Balance'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transaction History',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child:
                transactions.isEmpty
                    ? const Center(child: Text('No transactions yet'))
                    : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return _DebtTransactionTile(transaction: transaction);
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('delete-debt-profile'),
                  onPressed: () => _deleteProfile(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTransaction(BuildContext context, DebtTransactionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DebtTransactionFormScreen(profileId: profileId, type: type),
      ),
    );
  }

  Future<void> _rename(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Rename Profile'),
            content: TextField(
              key: const Key('rename-debt-profile-field'),
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, value.trim());
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                },
                child: const Text('Rename'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (newName == null || !context.mounted) return;
    await context.read<TransactionProvider>().renameDebtProfile(
      profileId,
      newName,
    );
  }

  Future<void> _deleteProfile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Profile?'),
            content: const Text(
              'The profile will move to Archive with its history intact.',
            ),
            actions: [
              TextButton(
                key: const Key('cancel-delete-debt-profile'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-delete-debt-profile'),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<TransactionProvider>().deleteDebtProfile(profileId);
    if (context.mounted) Navigator.pop(context);
  }
}

class _DebtTransactionTile extends StatelessWidget {
  final DebtTransaction transaction;

  const _DebtTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
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

    return ListTile(
      key: Key('debt-transaction-${transaction.id}'),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => DebtTransactionDetailScreen(
                    transactionId: transaction.id!,
                  ),
            ),
          ),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(switch (transaction.type) {
          DebtTransactionType.gave => Icons.arrow_upward,
          DebtTransactionType.received => Icons.arrow_downward,
          DebtTransactionType.update => Icons.sync_alt,
        }),
      ),
      title: Text(transaction.type.label),
      subtitle: Text(
        [
          if (transaction.note?.isNotEmpty == true) transaction.note!,
          DateFormat('MMM d, yyyy - h:mm a').format(transaction.createdAt!),
        ].join('\n'),
      ),
      trailing: Text(
        amount,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      isThreeLine: transaction.note?.isNotEmpty == true,
    );
  }
}
