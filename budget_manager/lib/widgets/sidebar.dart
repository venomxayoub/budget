import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Sidebar extends StatefulWidget {
  final String activePage;
  final ValueChanged<String> onPageChanged;
  final Future<void> Function() onImportDatabase;

  const Sidebar({
    super.key,
    required this.activePage,
    required this.onPageChanged,
    required this.onImportDatabase,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late bool _archiveExpanded = widget.activePage.startsWith('archive_');

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: const Text('Import Previous Data'),
              subtitle: const Text('Select a legacy .db file'),
              onTap: widget.onImportDatabase,
            ),
            _UpdateButton(),
            const Spacer(),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'Entries',
              isActive: widget.activePage == 'entries',
              onTap: () => widget.onPageChanged('entries'),
            ),
            _NavItem(
              icon: Icons.autorenew,
              label: 'Subscriptions',
              isActive: widget.activePage == 'subscriptions',
              onTap: () => widget.onPageChanged('subscriptions'),
            ),
            _NavItem(
              icon: Icons.category,
              label: 'Categories',
              isActive: widget.activePage == 'categories',
              onTap: () => widget.onPageChanged('categories'),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Debts & Loans',
              isActive: widget.activePage == 'debts',
              onTap: () => widget.onPageChanged('debts'),
            ),
            ExpansionTile(
              key: const Key('archive-navigation'),
              initiallyExpanded: _archiveExpanded,
              onExpansionChanged:
                  (expanded) => setState(() => _archiveExpanded = expanded),
              leading: Icon(
                Icons.archive,
                color:
                    widget.activePage.startsWith('archive_')
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: Text(
                'Archive',
                style: TextStyle(
                  fontWeight:
                      widget.activePage.startsWith('archive_')
                          ? FontWeight.w600
                          : FontWeight.normal,
                ),
              ),
              childrenPadding: const EdgeInsets.only(left: 24),
              children: [
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Entries',
                  isActive: widget.activePage == 'archive_entries',
                  onTap: () => widget.onPageChanged('archive_entries'),
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: 'Debt Profiles',
                  isActive: widget.activePage == 'archive_debt_profiles',
                  onTap: () => widget.onPageChanged('archive_debt_profiles'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      trailing:
          isActive
              ? Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
              : null,
      onTap: onTap,
    );
  }
}

class _UpdateButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const version = '1.3.2';
    const downloadUrl =
        'https://github.com/venomxayoub/budget/releases/download/v$version/BudgetManager-v$version.apk';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v$version',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed:
                  () => launchUrl(
                    Uri.parse(downloadUrl),
                    mode: LaunchMode.externalApplication,
                  ),
              icon: Icon(Icons.download, size: 18, color: colorScheme.primary),
              label: const Text('Update'),
            ),
          ),
        ],
      ),
    );
  }
}
