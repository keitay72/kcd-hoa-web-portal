import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/address_normalizer.dart';
import '../domain/hoa_address.dart';
import '../domain/hoa_address_input.dart';
import 'address_providers.dart';

class AddressFormDialog extends ConsumerStatefulWidget {
  const AddressFormDialog({
    this.initialValue,
    this.initialHoaId,
    super.key,
  });

  final HoaAddress? initialValue;
  final String? initialHoaId;

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String? _hoaId;
  bool _isActive = true;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    _hoaId = initialValue?.hoaId ?? widget.initialHoaId;

    if (initialValue != null) {
      _line1Controller.text = initialValue.line1;
      _line2Controller.text = initialValue.line2 ?? '';
      _cityController.text = initialValue.city;
      _stateController.text = initialValue.state;
      _postalCodeController.text = initialValue.postalCode;
      _isActive = initialValue.isActive;
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
    final formState = ref.watch(addressFormControllerProvider);
    final hoas = ref.watch(hoaListProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Address' : 'Create Address'),
      content: SizedBox(
        width: 640,
        child: hoas.when(
          data: (items) => _buildForm(context, formState, items),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Unable to load HOA communities: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: formState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
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
          label: Text(_isEditing ? 'Save changes' : 'Create address'),
        ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    AsyncValue<void> formState,
    List<HoaCommunity> hoas,
  ) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _hoaId,
              decoration: const InputDecoration(
                labelText: 'HOA Community',
                border: OutlineInputBorder(),
              ),
              items: hoas
                  .map(
                    (hoa) => DropdownMenuItem(
                      value: hoa.id,
                      child: Text('${hoa.name} (${hoa.code})'),
                    ),
                  )
                  .toList(),
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (value) => setState(() => _hoaId = value),
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active address'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
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

    final input = HoaAddressInput(
      hoaId: _hoaId!,
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      isActive: _isActive,
    );

    final controller = ref.read(addressFormControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateAddress(id: widget.initialValue!.id, input: input)
        : await controller.create(input);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
