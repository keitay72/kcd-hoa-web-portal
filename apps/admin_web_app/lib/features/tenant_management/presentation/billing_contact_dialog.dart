import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class BillingContactDialog extends ConsumerStatefulWidget {
  const BillingContactDialog({
    required this.tenantId,
    this.contact,
    super.key,
  });

  final String tenantId;
  final TenantBillingContact? contact;

  @override
  ConsumerState<BillingContactDialog> createState() => _BillingContactDialogState();
}

class _BillingContactDialogState extends ConsumerState<BillingContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late bool _isPrimary;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _name = TextEditingController(text: contact?.name ?? '');
    _email = TextEditingController(text: contact?.email ?? '');
    _phone = TextEditingController(text: contact?.phone ?? '');
    _isPrimary = contact?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    return AlertDialog(
      title: Text(widget.contact == null ? 'Add Billing Contact' : 'Edit Billing Contact'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Name is required.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPrimary,
                onChanged: (value) => setState(() => _isPrimary = value ?? false),
                title: const Text('Primary billing contact'),
              ),
              if (state.hasError)
                Text(
                  'Unable to save billing contact: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save Contact'),
        ),
      ],
    );
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'Enter a valid email.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(tenantMutationControllerProvider.notifier).saveBillingContact(
          tenantId: widget.tenantId,
          contactId: widget.contact?.id,
          input: TenantBillingContactInput(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            isPrimary: _isPrimary,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
