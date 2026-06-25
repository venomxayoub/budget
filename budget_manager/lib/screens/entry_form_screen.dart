import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_badge.dart';

class EntryFormScreen extends StatefulWidget {
  final bool isExpense;

  const EntryFormScreen({super.key, required this.isExpense});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  final Set<int> _selectedCategoryIds = {};

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a price')),
      );
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();

    if (widget.isExpense) {
      final expense = Expense(
        categoryIds: _selectedCategoryIds.toList(),
        price: price,
        note: _noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      provider.addExpense(expense);
    } else {
      final income = Income(
        categoryIds: _selectedCategoryIds.toList(),
        price: price,
        note: _noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
      provider.addIncome(income);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = widget.isExpense ? Colors.redAccent : Colors.green;

    final categories = provider.getCategoriesList(widget.isExpense);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isExpense ? 'Add Expense' : 'Add Income'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final selected = _selectedCategoryIds.contains(cat.id);
                return CategoryBadge(
                  emoji: cat.emoji,
                  name: cat.name,
                  isSelected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.remove(cat.id);
                      } else {
                        _selectedCategoryIds.add(cat.id!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isExpense ? 'Add Expense' : 'Add Income',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
