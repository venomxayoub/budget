import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subscription.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import 'subscription_detail_screen.dart';
import 'subscription_form_screen.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptions = context.watch<TransactionProvider>().subscriptions;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Subscriptions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('new-subscription'),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionFormScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                subscriptions.isEmpty
                    ? const _EmptySubscriptions()
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: subscriptions.length,
                      itemBuilder:
                          (context, index) => _SubscriptionCard(
                            subscription: subscriptions[index],
                          ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (subscription.status) {
      SubscriptionStatus.active => Colors.green,
      SubscriptionStatus.paused => Colors.orange,
      SubscriptionStatus.cancelled => Colors.redAccent,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: Key('subscription-${subscription.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          foregroundColor: statusColor,
          child: const Icon(Icons.autorenew),
        ),
        title: Text(
          subscription.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${subscription.period.label} · Next ${DateFormat.yMMMd().format(subscription.nextRenewalDate)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(subscription.priceCents),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              subscription.status.label,
              style: TextStyle(fontSize: 12, color: statusColor),
            ),
          ],
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => SubscriptionDetailScreen(
                      subscriptionId: subscription.id!,
                    ),
              ),
            ),
      ),
    );
  }
}

class _EmptySubscriptions extends StatelessWidget {
  const _EmptySubscriptions();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.autorenew,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        const Text('No subscriptions yet'),
        const SizedBox(height: 6),
        Text(
          'Tap New to add a recurring expense',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    ),
  );
}
