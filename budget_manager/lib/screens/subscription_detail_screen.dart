import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/subscription.dart';
import '../models/subscription_status_event.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import 'entry_detail_screen.dart';
import 'subscription_form_screen.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  final int subscriptionId;

  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final subscription = provider.getSubscriptionById(subscriptionId);
    if (subscription == null) {
      return const Scaffold(
        body: Center(child: Text('Subscription not found')),
      );
    }
    final timeline = <_TimelineItem>[
      for (final payment in provider.subscriptionPayments(subscriptionId))
        _TimelineItem(payment: payment),
      for (final event in provider.subscriptionStatusEvents(subscriptionId))
        _TimelineItem(statusEvent: event),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final statusColor = switch (subscription.status) {
      SubscriptionStatus.active => Colors.green,
      SubscriptionStatus.paused => Colors.orange,
      SubscriptionStatus.cancelled => Colors.redAccent,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(subscription.name),
        actions: [
          IconButton(
            key: const Key('edit-subscription'),
            tooltip: 'Edit',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            SubscriptionFormScreen(subscription: subscription),
                  ),
                ),
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatCurrency(subscription.priceCents),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${subscription.period.label} · ${subscription.status.label}',
                        style: TextStyle(color: statusColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Next renewal: ${DateFormat.yMMMMd().format(subscription.nextRenewalDate)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (subscription.status == SubscriptionStatus.active)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('pause-subscription'),
                          onPressed:
                              () => _changeStatus(
                                context,
                                title: 'Pause Subscription?',
                                message:
                                    'No payments will be created until you unpause it.',
                                actionLabel: 'Pause',
                                action:
                                    () => provider.pauseSubscription(
                                      subscriptionId,
                                    ),
                              ),
                          icon: const Icon(Icons.pause_outlined),
                          label: const Text('Pause'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('cancel-subscription'),
                          onPressed:
                              () => _changeStatus(
                                context,
                                title: 'Cancel Subscription?',
                                message:
                                    'No payments will be created until you uncancel it.',
                                actionLabel: 'Cancel',
                                action:
                                    () => provider.cancelSubscription(
                                      subscriptionId,
                                    ),
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('reactivate-subscription'),
                      onPressed:
                          () => _changeStatus(
                            context,
                            title:
                                subscription.status == SubscriptionStatus.paused
                                    ? 'Unpause Subscription?'
                                    : 'Uncancel Subscription?',
                            message:
                                'This charges today and schedules the next renewal from today.',
                            actionLabel:
                                subscription.status == SubscriptionStatus.paused
                                    ? 'Unpause'
                                    : 'Uncancel',
                            action:
                                () => provider.reactivateSubscription(
                                  subscriptionId,
                                ),
                          ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        subscription.status == SubscriptionStatus.paused
                            ? 'Unpause and Charge Today'
                            : 'Uncancel and Charge Today',
                      ),
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
                'History',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child:
                timeline.isEmpty
                    ? const Center(child: Text('No history yet'))
                    : ListView.separated(
                      itemCount: timeline.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = timeline[index];
                        if (item.payment != null) {
                          return _PaymentTile(payment: item.payment!);
                        }
                        return _StatusTile(event: item.statusEvent!);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(actionLabel),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    await action();
  }
}

class _PaymentTile extends StatelessWidget {
  final Expense payment;

  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('subscription-payment-${payment.id}'),
    leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
    title: const Text('Payment'),
    subtitle: Text(
      DateFormat.yMMMMd().format(
        payment.subscriptionScheduledDate ?? payment.createdAt!,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatCurrency(payment.amountCents),
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          key: Key('delete-subscription-payment-${payment.id}'),
          tooltip: 'Delete payment',
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    onTap: () {
      final entry = context.read<TransactionProvider>().getEntryById(
        id: payment.id!,
        isExpense: true,
      );
      if (entry == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EntryDetailScreen(entry: entry)),
      );
    },
  );

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Payment?'),
            content: const Text(
              'This moves the shared expense to the Entries archive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<TransactionProvider>().deleteExpense(payment.id!);
  }
}

class _StatusTile extends StatelessWidget {
  final SubscriptionStatusEvent event;

  const _StatusTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch ((event.fromStatus, event.toStatus)) {
      (null, SubscriptionStatus.active) => (
        'Subscription created',
        Icons.add_circle_outline,
        Colors.green,
      ),
      (SubscriptionStatus.paused, SubscriptionStatus.active) => (
        'Subscription unpaused',
        Icons.play_arrow,
        Colors.green,
      ),
      (SubscriptionStatus.cancelled, SubscriptionStatus.active) => (
        'Subscription uncancelled',
        Icons.restart_alt,
        Colors.green,
      ),
      (_, SubscriptionStatus.paused) => (
        'Subscription paused',
        Icons.pause_outlined,
        Colors.orange,
      ),
      (_, SubscriptionStatus.cancelled) => (
        'Subscription cancelled',
        Icons.cancel_outlined,
        Colors.redAccent,
      ),
      _ => ('Status changed', Icons.sync, Colors.blue),
    };
    return ListTile(
      key: Key('subscription-status-event-${event.id}'),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(label),
      subtitle: Text(DateFormat.yMMMd().add_jm().format(event.occurredAt)),
    );
  }
}

class _TimelineItem {
  final Expense? payment;
  final SubscriptionStatusEvent? statusEvent;

  const _TimelineItem({this.payment, this.statusEvent})
    : assert(payment != null || statusEvent != null);

  DateTime get date => payment?.createdAt ?? statusEvent!.occurredAt;
}
