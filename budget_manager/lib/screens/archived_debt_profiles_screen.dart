import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../utils/currency.dart';
import '../utils/debt_display.dart';

class ArchivedDebtProfilesScreen extends StatelessWidget {
  const ArchivedDebtProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final profiles = provider.archivedDebtProfiles;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Archived Debt Profiles',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                profiles.isEmpty
                    ? const Center(child: Text('No archived debt profiles'))
                    : ListView.separated(
                      itemCount: profiles.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final balance = provider.debtBalanceForProfile(
                          profile.id!,
                        );
                        return ListTile(
                          key: Key('archived-debt-profile-${profile.id}'),
                          leading: const Icon(Icons.person_off_outlined),
                          title: Text(profile.name),
                          subtitle: Text(
                            '${formatSignedCurrency(balance)} · ${debtBalanceLabel(balance)}',
                            style: TextStyle(color: debtBalanceColor(balance)),
                          ),
                          trailing: OutlinedButton.icon(
                            key: Key('restore-debt-profile-${profile.id}'),
                            onPressed:
                                () => context
                                    .read<TransactionProvider>()
                                    .restoreDebtProfile(profile.id!),
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore'),
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
