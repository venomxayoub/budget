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
  final _selectedCategoryIds = <int>{};
  final _priceFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    _priceFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = context.read<TransactionProvider>();

    var categoryIds = _selectedCategoryIds.toList();
    if (categoryIds.isEmpty) {
      final cats = provider.getCategoriesList(widget.isExpense);
      final other = cats.cast<dynamic>().firstWhere(
        (c) => c.name == 'Other',
        orElse: () => cats.first,
      );
      categoryIds = [other.id as int];
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

    if (widget.isExpense) {
      final expense = Expense(
        categoryIds: categoryIds,
        price: price,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      provider.addExpense(expense);
    } else {
      final income = Income(
        categoryIds: categoryIds,
        price: price,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      provider.addIncome(income);
    }

    _priceController.clear();
    _noteController.clear();
    _selectedCategoryIds.clear();
    setState(() {});
    _priceFocusNode.requestFocus();
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
              focusNode: _priceFocusNode,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
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
              onSubmitted: (_) => _noteFocusNode.requestFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              focusNode: _noteFocusNode,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _submit(),
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
