import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense_category.dart';
import '../models/income_category.dart';
import '../providers/transaction_provider.dart';

class CategoryFormScreen extends StatefulWidget {
  final bool isExpense;

  const CategoryFormScreen({super.key, required this.isExpense});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emojiFocusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _nameFocusNode.dispose();
    _emojiFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final emoji = _emojiController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    if (emoji.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an emoji')),
      );
      return;
    }

    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();

    if (widget.isExpense) {
      provider.addExpenseCategory(
        ExpenseCategory(
          name: name,
          emoji: emoji,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      provider.addIncomeCategory(
        IncomeCategory(
          name: name,
          emoji: emoji,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isExpense ? Colors.redAccent : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isExpense ? 'Add Expense Category' : 'Add Income Category'),
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
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
