import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/debt_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class DebtTransactionFormScreen extends StatefulWidget {
  final int profileId;
  final DebtTransactionType type;

  const DebtTransactionFormScreen({
    super.key,
    required this.profileId,
    required this.type,
  });

  @override
  State<DebtTransactionFormScreen> createState() =>
      _DebtTransactionFormScreenState();
}

class _DebtTransactionFormScreenState extends State<DebtTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;

  bool get _isUpdate => widget.type == DebtTransactionType.update;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final amountCents =
        _isUpdate
            ? parseSignedCurrencyToCents(_amountController.text)!
            : parseCurrencyToCents(_amountController.text)!;

    setState(() => _submitting = true);
    try {
      await context.read<TransactionProvider>().addDebtTransaction(
        profileId: widget.profileId,
        type: widget.type,
        amountCents: amountCents,
        note: _noteController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save transaction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (widget.type) {
      DebtTransactionType.gave => Colors.blue,
      DebtTransactionType.received => Colors.red,
      DebtTransactionType.update => Colors.green,
    };
    final profile = context.read<TransactionProvider>().getDebtProfileById(
      widget.profileId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdate ? 'Update Balance' : widget.type.label),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (profile != null) ...[
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('debt-transaction-amount'),
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: _isUpdate,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(
                    _isUpdate ? r'^[+-]?\d*\.?\d{0,2}' : r'^\d*\.?\d{0,2}',
                  ),
                ),
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _isUpdate ? 'New absolute balance' : 'Amount',
                prefixText: r'$ ',
                helperText:
                    _isUpdate
                        ? 'Enter the complete signed balance, not a difference.'
                        : null,
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
              ),
              validator: (value) {
                if (_isUpdate) {
                  return parseSignedCurrencyToCents(value ?? '') == null
                      ? 'Enter a valid signed balance'
                      : null;
                }
                final parsed = parseCurrencyToCents(value ?? '');
                return parsed == null || parsed <= 0
                    ? 'Amount must be positive'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('debt-transaction-note'),
              controller: _noteController,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('save-debt-transaction'),
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: accentColor),
            child: Text(_submitting ? 'Saving...' : 'Save'),
          ),
        ),
      ),
    );
  }
}
