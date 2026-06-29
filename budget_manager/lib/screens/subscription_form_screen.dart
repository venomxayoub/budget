import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subscription.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency.dart';

class SubscriptionFormScreen extends StatefulWidget {
  final Subscription? subscription;

  const SubscriptionFormScreen({super.key, this.subscription});

  bool get isEditing => subscription != null;

  @override
  State<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends State<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late SubscriptionPeriod _period;
  late DateTime _renewalDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    _nameController = TextEditingController(text: subscription?.name ?? '');
    _priceController = TextEditingController(
      text:
          subscription == null
              ? ''
              : formatCurrency(subscription.priceCents).substring(1),
    );
    _period = subscription?.period ?? SubscriptionPeriod.monthly;
    _renewalDate = _dateOnly(subscription?.nextRenewalDate ?? DateTime.now());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final initial = _renewalDate.isBefore(today) ? today : _renewalDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 20, 12, 31),
    );
    if (selected != null) setState(() => _renewalDate = selected);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final priceCents = parseCurrencyToCents(_priceController.text)!;
    setState(() => _submitting = true);
    try {
      final provider = context.read<TransactionProvider>();
      final existing = widget.subscription;
      if (existing == null) {
        await provider.createSubscription(
          name: _nameController.text,
          priceCents: priceCents,
          period: _period,
          firstRenewalDate: _renewalDate,
        );
      } else {
        await provider.updateSubscription(
          id: existing.id!,
          name: _nameController.text,
          priceCents: priceCents,
          period: _period,
          nextRenewalDate: _renewalDate,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save subscription: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isEditing ? 'Edit Subscription' : 'New Subscription'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('subscription-name'),
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
            key: const Key('subscription-price'),
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixText: r'$ ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final cents = parseCurrencyToCents(value ?? '');
              return cents == null || cents <= 0
                  ? 'Enter a valid positive price'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SubscriptionPeriod>(
            key: const Key('subscription-period'),
            value: _period,
            decoration: const InputDecoration(
              labelText: 'Frequency',
              border: OutlineInputBorder(),
            ),
            items:
                SubscriptionPeriod.values
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(period.label),
                      ),
                    )
                    .toList(),
            onChanged: (period) {
              if (period != null) setState(() => _period = period);
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('subscription-renewal-date'),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            title: const Text('Next renewal date'),
            subtitle: Text(DateFormat.yMMMMd().format(_renewalDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDate,
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 8),
            Text(
              'Changing these fields does not create a payment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('save-subscription'),
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting
                ? 'Saving...'
                : widget.isEditing
                ? 'Save Changes'
                : 'Create Subscription',
          ),
        ),
      ),
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
