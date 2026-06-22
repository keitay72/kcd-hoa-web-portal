import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/customer_account.dart';
import '../domain/customer_account_input.dart';
import 'customer_account_providers.dart';

class CustomerAccountFormDialog extends ConsumerStatefulWidget {
  const CustomerAccountFormDialog({
    this.initialValue,
    this.tenantId,
    super.key,
  });

  final CustomerAccount? initialValue;
  final String? tenantId;

  @override
  ConsumerState<CustomerAccountFormDialog> createState() =>
      _CustomerAccountFormDialogState();
}

class _CustomerAccountFormDialogState
    extends ConsumerState<CustomerAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _externalRefController = TextEditingController();

  CustomerAccountType _accountType = CustomerAccountType.residential;
  CustomerAccountStatus _status = CustomerAccountStatus.active;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    if (initialValue != null) {
      _accountNumberController.text = initialValue.accountNumber ?? '';
      _nameController.text = initialValue.name ?? '';
      _externalRefController.text = initialValue.externalAccountRef ?? '';
      _accountType = initialValue.accountType;
      _status = initialValue.status;
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _nameController.dispose();
    _externalRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(customerAccountFormControllerProvider);

    return AlertDialog(
      title: Text(
          _isEditing ? 'Edit Customer Account' : 'Create Customer Account'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<CustomerAccountType>(
                  initialValue: _accountType,
                  decoration: const InputDecoration(
                    labelText: 'Account Type',
                    border: OutlineInputBorder(),
                  ),
                  items: CustomerAccountType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _accountType = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<CustomerAccountStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: CustomerAccountStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _externalRefController,
                  decoration: const InputDecoration(
                    labelText: 'External Account Reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (formState.hasError) ...[
                  const SizedBox(height: 14),
                  Text(
                    formState.error.toString(),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              formState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: formState.isLoading ? null : _submit,
          icon: formState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Save changes' : 'Create account'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = CustomerAccountInput(
      accountNumber: _accountNumberController.text,
      accountType: _accountType,
      name: _nameController.text,
      status: _status,
      externalAccountRef: _externalRefController.text,
    );

    final controller = ref.read(customerAccountFormControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateAccount(
            id: widget.initialValue!.id,
            input: input,
          )
        : await controller.create(input, tenantId: widget.tenantId);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
