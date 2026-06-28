import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class DebtProfileFormScreen extends StatefulWidget {
  const DebtProfileFormScreen({super.key});

  @override
  State<DebtProfileFormScreen> createState() => _DebtProfileFormScreenState();
}

class _DebtProfileFormScreenState extends State<DebtProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final initialBalance = parseSignedCurrencyToCents(_balanceController.text)!;

    setState(() => _submitting = true);
    try {
      await context.read<TransactionProvider>().createDebtProfile(
        name: _nameController.text,
        initialBalanceCents: initialBalance,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Debt Profile')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('debt-profile-name'),
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            validator:
                (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('debt-initial-balance'),
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^[+-]?\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Initial balance',
              prefixText: r'$ ',
              helperText: 'Positive: they owe you. Negative: you owe them.',
              border: OutlineInputBorder(),
            ),
            validator:
                (value) =>
                    parseSignedCurrencyToCents(value ?? '') == null
                        ? 'Enter a valid signed balance'
                        : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('save-debt-profile'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Saving...' : 'Create Profile'),
        ),
      ),
    ),
  );
}
