import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address_registry/domain/address_normalizer.dart';
import '../../hoa_management/domain/hoa_community.dart';
import '../domain/customer_account.dart';
import '../domain/customer_account_input.dart';
import '../domain/service_location.dart';
import '../domain/service_location_input.dart';
import 'customer_account_providers.dart';

class ServiceAddressFormDialog extends ConsumerStatefulWidget {
  const ServiceAddressFormDialog({
    required this.tenantId,
    required this.accounts,
    required this.communities,
    super.key,
  });

  final String? tenantId;
  final List<CustomerAccount> accounts;
  final List<HoaCommunity> communities;

  @override
  ConsumerState<ServiceAddressFormDialog> createState() =>
      _ServiceAddressFormDialogState();
}

class _ServiceAddressFormDialogState
    extends ConsumerState<ServiceAddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'MO');
  final _postalCodeController = TextEditingController();
  final _externalRefController = TextEditingController();

  bool _belongsToCommunity = false;
  String? _communityId;
  bool _isSubmitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
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
    return AlertDialog(
      title: const Text('Add Service Address'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.home_outlined),
                      label: Text('Standalone'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.apartment_outlined),
                      label: Text('Community'),
                    ),
                  ],
                  selected: {_belongsToCommunity},
                  onSelectionChanged: _isSubmitting
                      ? null
                      : (selection) {
                          setState(() {
                            _belongsToCommunity = selection.first;
                            _communityId = null;
                          });
                        },
                ),
                const SizedBox(height: 14),
                if (_belongsToCommunity) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _communityId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Community',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.communities
                        .map(
                          (community) => DropdownMenuItem(
                            value: community.id,
                            child: Text(
                              community.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => _belongsToCommunity && value == null
                        ? 'Select a community'
                        : null,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _communityId = value),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _line1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _line2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Unit / Apt',
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
                          labelText: 'ZIP Code',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
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
                Text(
                  'Normalized key: ${_normalizedPreview()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error.toString(),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Address'),
        ),
      ],
    );
  }

  void _refreshNormalizedPreview() {
    setState(() {});
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _validateState(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final account = await _resolveAccount();
      final input = ServiceLocationInput(
        customerAccountId: account.id,
        line1: _line1Controller.text,
        line2: _line2Controller.text,
        city: _cityController.text,
        state: _stateController.text,
        postalCode: _postalCodeController.text,
        status: ServiceLocationStatus.active,
        externalLocationRef: _externalRefController.text,
        metadata: _serviceLocationMetadata(),
      );

      final location = await ref
          .read(customerAccountRepositoryProvider)
          .createServiceLocation(input, tenantId: widget.tenantId);

      ref.invalidate(customerAccountListProvider);
      ref.invalidate(serviceLocationListProvider);

      if (mounted) Navigator.of(context).pop(location);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isSubmitting = false;
        });
      }
    }
  }

  Future<CustomerAccount> _resolveAccount() async {
    if (!_belongsToCommunity) {
      return ref.read(customerAccountRepositoryProvider).createAccount(
            CustomerAccountInput(
              accountType: CustomerAccountType.residential,
              status: CustomerAccountStatus.active,
              name: _singleLineAddress(),
            ),
            tenantId: widget.tenantId,
          );
    }

    final communityId = _communityId;
    final community = widget.communities.firstWhere(
      (item) => item.id == communityId,
      orElse: () => throw StateError('Select a community.'),
    );

    for (final account in widget.accounts) {
      final legacyHoaId = account.metadata['legacy_hoa_id']?.toString();
      if (account.accountType == CustomerAccountType.community &&
          (account.externalAccountRef == community.id ||
              legacyHoaId == community.id)) {
        return account;
      }
    }

    return ref.read(customerAccountRepositoryProvider).createAccount(
          CustomerAccountInput(
            accountType: CustomerAccountType.community,
            status: CustomerAccountStatus.active,
            name: community.name,
            externalAccountRef: community.id,
            metadata: {'legacy_hoa_id': community.id},
          ),
          tenantId: widget.tenantId,
        );
  }

  Map<String, dynamic> _serviceLocationMetadata() {
    if (!_belongsToCommunity || _communityId == null) return const {};
    return {'legacy_hoa_id': _communityId};
  }

  String _singleLineAddress() {
    return <String?>[
      _line1Controller.text.trim(),
      _line2Controller.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _postalCodeController.text.trim(),
    ].where((part) => part != null && part.isNotEmpty).join(', ');
  }
}
