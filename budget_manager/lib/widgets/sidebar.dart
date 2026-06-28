import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Sidebar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'Entries',
              isActive: activePage == 'entries',
              onTap: () => onPageChanged('entries'),
            ),
            _NavItem(
              icon: Icons.category,
              label: 'Categories',
              isActive: activePage == 'categories',
              onTap: () => onPageChanged('categories'),
            ),
            _NavItem(
              icon: Icons.archive,
              label: 'Archive',
              isActive: activePage == 'archive',
              onTap: () => onPageChanged('archive'),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: const Text('Import Previous Data'),
              subtitle: const Text('Select a legacy .db file'),
              onTap: onImportDatabase,
            ),
            _UpdateButton(),
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
    const version = '1.0.4';
    const downloadUrl =
        'https://github.com/venomxayoub/budget/releases/latest/download/app-release.apk';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
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
