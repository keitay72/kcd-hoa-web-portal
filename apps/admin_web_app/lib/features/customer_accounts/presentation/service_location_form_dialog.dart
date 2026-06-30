import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address_registry/domain/address_normalizer.dart';
import '../domain/customer_account.dart';
import '../domain/customer_account_input.dart';
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

  String? _customerAccountId;
  ServiceLocationStatus _status = ServiceLocationStatus.active;
  Object? _localError;

  bool get _isEditing => widget.initialValue != null;

  List<CustomerAccount> get _communityAccounts {
    final accounts = widget.accounts.where(_isHoaCommunityAccount).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return accounts;
  }

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
      _status = initialValue.status;
    }

    if (_customerAccountId != null) {
      final selectedAccount = _accountById(_customerAccountId!);
      if (selectedAccount == null || !_isHoaCommunityAccount(selectedAccount)) {
        _customerAccountId = null;
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(serviceLocationFormControllerProvider);
    final visibleError = formState.error ?? _localError;

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Service Address' : 'Add Service Address',
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                DropdownButtonFormField<String?>(
                  key: ValueKey(_customerAccountId ?? 'no-community'),
                  initialValue: _customerAccountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Community / HOA (optional)',
                    helperText:
                        'Leave blank for city-wide residential service.',
                    border: const OutlineInputBorder(),
                    suffixIcon: _customerAccountId == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear community',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _customerAccountId = null);
                            },
                          ),
                  ),
                  items: _communityAccounts
                      .map(
                        (account) => DropdownMenuItem<String?>(
                          value: account.id,
                          child: Text(
                            account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _customerAccountId = value),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Normalized key: ${_normalizedPreview()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (visibleError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    visibleError.toString(),
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

    setState(() => _localError = null);

    final String? accountId;
    try {
      accountId = await _resolveLocationAccountId();
    } catch (error) {
      if (mounted) {
        setState(() => _localError = error);
      }
      return;
    }

    if (accountId == null) {
      return;
    }

    final input = ServiceLocationInput(
      customerAccountId: accountId,
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      status: _status,
      externalLocationRef: widget.initialValue?.externalLocationRef,
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

  Future<String?> _resolveLocationAccountId() async {
    final selectedCommunityId = _customerAccountId;
    if (selectedCommunityId != null) return selectedCommunityId;

    final existingCityAccount = _findCityAccount();
    if (existingCityAccount != null) return existingCityAccount.id;

    final tenantId = widget.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _localError = StateError(
            'Unable to create a city service area for this address.');
      });
      return null;
    }

    final city = _titleCase(_cityController.text);
    final state = _stateController.text.trim().toUpperCase();
    final repository = ref.read(customerAccountRepositoryProvider);
    final cityAccount = await repository.createAccount(
      CustomerAccountInput(
        accountType: CustomerAccountType.community,
        status: CustomerAccountStatus.active,
        name: _cityScopeName(city: city, state: state),
        metadata: {
          'community_type': 'city',
          'city': city,
          'state': state,
        },
      ),
      tenantId: tenantId,
    );

    ref.invalidate(customerAccountListProvider);
    return cityAccount.id;
  }

  CustomerAccount? _findCityAccount() {
    final city = _cityController.text.trim().toLowerCase();
    final state = _stateController.text.trim().toUpperCase();
    for (final account in widget.accounts) {
      if (!_isCityAccount(account)) continue;
      final accountCity =
          (account.metadata['city'] ?? '').toString().trim().toLowerCase();
      final accountState =
          (account.metadata['state'] ?? '').toString().trim().toUpperCase();
      if (accountCity == city && accountState == state) return account;

      final displayName = account.displayName.trim().toLowerCase();
      if (displayName ==
          _cityScopeName(city: city, state: state).toLowerCase()) {
        return account;
      }
    }

    return null;
  }

  CustomerAccount? _accountById(String id) {
    for (final account in widget.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  bool _isHoaCommunityAccount(CustomerAccount account) {
    return account.accountType == CustomerAccountType.community &&
        !_isCityAccount(account);
  }

  bool _isCityAccount(CustomerAccount account) {
    return account.accountType == CustomerAccountType.community &&
        account.metadata['community_type'] == 'city';
  }

  String _cityScopeName({required String city, required String state}) {
    return [city, state].where((part) => part.trim().isNotEmpty).join(', ');
  }

  String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length == 1) return part.toUpperCase();
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join(' ');
  }
}
