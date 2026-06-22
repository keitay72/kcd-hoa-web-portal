import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address_registry/domain/address_normalizer.dart';
import '../domain/customer_account.dart';
import '../domain/service_location.dart';
import '../domain/service_location_input.dart';
import 'customer_account_providers.dart';

class ServiceLocationFormDialog extends ConsumerStatefulWidget {
  const ServiceLocationFormDialog({
    required this.accounts,
    this.initialValue,
    this.initialAccountId,
    this.tenantId,
    super.key,
  });

  final List<CustomerAccount> accounts;
  final ServiceLocation? initialValue;
  final String? initialAccountId;
  final String? tenantId;

  @override
  ConsumerState<ServiceLocationFormDialog> createState() =>
      _ServiceLocationFormDialogState();
}

class _ServiceLocationFormDialogState
    extends ConsumerState<ServiceLocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _externalRefController = TextEditingController();

  String? _customerAccountId;
  ServiceLocationStatus _status = ServiceLocationStatus.active;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    _customerAccountId =
        initialValue?.customerAccountId ?? widget.initialAccountId;

    if (initialValue != null) {
      _line1Controller.text = initialValue.line1;
      _line2Controller.text = initialValue.line2 ?? '';
      _cityController.text = initialValue.city;
      _stateController.text = initialValue.state;
      _postalCodeController.text = initialValue.postalCode;
      _externalRefController.text = initialValue.externalLocationRef ?? '';
      _status = initialValue.status;
    }

    for (final controller in [
      _line1Controller,
      _line2Controller,
      _cityController,
      _stateController,
      _postalCodeController,
    ]) {
      controller.addListener(_refreshNormalizedPreview);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _line1Controller,
      _line2Controller,
      _cityController,
      _stateController,
      _postalCodeController,
    ]) {
      controller.removeListener(_refreshNormalizedPreview);
    }

    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _externalRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(serviceLocationFormControllerProvider);

    return AlertDialog(
      title: Text(
          _isEditing ? 'Edit Service Location' : 'Create Service Location'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _customerAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer Account',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null ? 'Required' : null,
                  onChanged: (value) =>
                      setState(() => _customerAccountId = value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _line1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _line2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: _validateState,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Postal Code',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ServiceLocationStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ServiceLocationStatus.values
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
                    labelText: 'External Location Reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Normalized key: ${_normalizedPreview()}',
                    style: Theme.of(context).textTheme.bodySmall,
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
          label: Text(_isEditing ? 'Save changes' : 'Create location'),
        ),
      ],
    );
  }

  void _refreshNormalizedPreview() {
    setState(() {});
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _validateState(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) {
      return requiredError;
    }

    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value!.trim())) {
      return 'Use 2 letters';
    }

    return null;
  }

  String _normalizedPreview() {
    return AddressNormalizer.normalizedKey(
      line1: _line1Controller.text,
      line2: _line2Controller.text,
      city: _cityController.text,
      state: _stateController.text,
      postalCode: _postalCodeController.text,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = ServiceLocationInput(
      customerAccountId: _customerAccountId!,
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      status: _status,
      externalLocationRef: _externalRefController.text,
    );

    final controller = ref.read(serviceLocationFormControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateServiceLocation(
            id: widget.initialValue!.id,
            input: input,
          )
        : await controller.create(input, tenantId: widget.tenantId);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
