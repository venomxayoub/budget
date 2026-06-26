import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final String activePage;
  final ValueChanged<String> onPageChanged;

  const Sidebar({
    super.key,
    required this.activePage,
    required this.onPageChanged,
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
      trailing: isActive
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
