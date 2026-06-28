import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../providers/transaction_provider.dart';

class CategoryFormScreen extends StatefulWidget {
  final bool isExpense;
  final ExpenseCategory? expenseCategory;
  final IncomeCategory? incomeCategory;

  const CategoryFormScreen({
    super.key,
    required this.isExpense,
    this.expenseCategory,
    this.incomeCategory,
  }) : assert(
         (isExpense && incomeCategory == null) ||
             (!isExpense && expenseCategory == null),
       );

  bool get isEditing => expenseCategory != null || incomeCategory != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emojiFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseCategory != null) {
      _nameController.text = widget.expenseCategory!.name;
      _emojiController.text = widget.expenseCategory!.emoji;
    } else if (widget.incomeCategory != null) {
      _nameController.text = widget.incomeCategory!.name;
      _emojiController.text = widget.incomeCategory!.emoji;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _nameFocusNode.dispose();
    _emojiFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    final emoji = _emojiController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    if (emoji.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an emoji')));
      return;
    }

    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();

    setState(() => _isSubmitting = true);
    try {
      if (widget.isExpense) {
        final existing = widget.expenseCategory;
        final category = ExpenseCategory(
          id: existing?.id,
          name: name,
          emoji: emoji,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        if (existing == null) {
          await provider.addExpenseCategory(category);
        } else {
          await provider.updateExpenseCategory(category);
        }
      } else {
        final existing = widget.incomeCategory;
        final category = IncomeCategory(
          id: existing?.id,
          name: name,
          emoji: emoji,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        if (existing == null) {
          await provider.addIncomeCategory(category);
        } else {
          await provider.updateIncomeCategory(category);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save category: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isExpense ? Colors.redAccent : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit ${widget.isExpense ? 'Expense' : 'Income'} Category'
              : 'Add ${widget.isExpense ? 'Expense' : 'Income'} Category',
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Groceries',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 18),
              onSubmitted: (_) => _emojiFocusNode.requestFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emojiController,
              focusNode: _emojiFocusNode,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Emoji',
                hintText: 'e.g. 🥦',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 24),
              onSubmitted: (_) => _submit(),
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
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.isEditing ? 'Save Changes' : 'Add',
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
