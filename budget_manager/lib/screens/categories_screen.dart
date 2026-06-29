import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_badge.dart';

class CategoriesScreen extends StatelessWidget {
  final ValueChanged<ExpenseCategory> onEditExpenseCategory;
  final ValueChanged<IncomeCategory> onEditIncomeCategory;
  final VoidCallback onNewExpenseCategory;
  final VoidCallback onNewIncomeCategory;

  const CategoriesScreen({
    super.key,
    required this.onEditExpenseCategory,
    required this.onEditIncomeCategory,
    required this.onNewExpenseCategory,
    required this.onNewIncomeCategory,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final expenseCats = provider.expenseCategories;
    final incomeCats = provider.incomeCategories;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Categories',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  key: const Key('new-expense-category'),
                  onPressed: onNewExpenseCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Expense'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('new-income-category'),
                  onPressed: onNewIncomeCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Income'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _SectionHeader(title: 'Expense Categories', color: Colors.redAccent),
                if (expenseCats.isEmpty)
                  const _EmptyItem()
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          expenseCats
                              .map(
                                (cat) => CategoryBadge(
                                  emoji: cat.emoji,
                                  name: cat.name,
                                  onTap: () => onEditExpenseCategory(cat),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionHeader(title: 'Income Categories', color: Colors.green),
                if (incomeCats.isEmpty)
                  const _EmptyItem()
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          incomeCats
                              .map(
                                (cat) => CategoryBadge(
                                  emoji: cat.emoji,
                                  name: cat.name,
                                  onTap: () => onEditIncomeCategory(cat),
                                ),
                              )
                              .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyItem extends StatelessWidget {
  const _EmptyItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'No categories yet. Tap + to add one.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 13,
        ),
      ),
    );
  }
}
