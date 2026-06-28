import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/debt_profile.dart';
import '../models/debt_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import '../utils/debt_display.dart';
import 'debt_profile_detail_screen.dart';
import 'debt_profile_form_screen.dart';
import 'debt_transaction_form_screen.dart';

class DebtProfilesScreen extends StatelessWidget {
  const DebtProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final profiles = provider.debtProfiles;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Debts & Loans',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('new-debt-profile'),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DebtProfileFormScreen(),
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
                profiles.isEmpty
                    ? const _EmptyDebtProfiles()
                    : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return _DebtProfileCard(
                          profile: profile,
                          balanceCents: provider.debtBalanceForProfile(
                            profile.id!,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _DebtProfileCard extends StatelessWidget {
  final DebtProfile profile;
  final int balanceCents;

  const _DebtProfileCard({required this.profile, required this.balanceCents});

  @override
  Widget build(BuildContext context) {
    final balanceColor = debtBalanceColor(balanceCents);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('debt-profile-${profile.id}'),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DebtProfileDetailScreen(profileId: profile.id!),
              ),
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatSignedCurrency(balanceCents),
                        key: Key('debt-balance-${profile.id}'),
                        style: TextStyle(
                          color: balanceColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        debtBalanceLabel(balanceCents),
                        style: TextStyle(fontSize: 11, color: balanceColor),
                      ),
                    ],
                  ),
                ],
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
            ],
          ),
        ),
      ),
    );
  }

  void _openTransaction(BuildContext context, DebtTransactionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                DebtTransactionFormScreen(profileId: profile.id!, type: type),
      ),
    );
  }
}

class _EmptyDebtProfiles extends StatelessWidget {
  const _EmptyDebtProfiles();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_balance_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        const Text('No debt profiles yet'),
        const SizedBox(height: 6),
        Text(
          'Tap New to start a personal ledger',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    ),
  );
}
