import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activation_code_address_option.dart';
import '../domain/activation_code_inputs.dart';
import 'activation_code_providers.dart';
import 'generated_code_result.dart';

class GenerateActivationCodeDialog extends ConsumerStatefulWidget {
  const GenerateActivationCodeDialog({
    this.initialAddressId,
    super.key,
  });

  final String? initialAddressId;

  @override
  ConsumerState<GenerateActivationCodeDialog> createState() =>
      _GenerateActivationCodeDialogState();
}

class _GenerateActivationCodeDialogState
    extends ConsumerState<GenerateActivationCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _daysController = TextEditingController(text: '30');
  final _reasonController = TextEditingController();
  String? _addressId;

  bool get _isAddressLocked => widget.initialAddressId != null;

  @override
  void initState() {
    super.initState();
    _addressId = widget.initialAddressId;
    Future.microtask(() {
      ref.read(activationCodeCommandProvider.notifier).clearGeneratedCode();
    });
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(activationCodeAddressOptionsProvider);
    final commandState = ref.watch(activationCodeCommandProvider);

    return AlertDialog(
      title: const Text('Generate Activation Code'),
      content: SizedBox(
        width: 680,
        child: addresses.when(
          data: (items) {
            final selectedAddress = _selectedAddressLabel(items);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAddressLocked)
                      TextFormField(
                        initialValue: selectedAddress ?? _addressId,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _addressId,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        items: items
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        validator: (value) => value == null ? 'Required' : null,
                        onChanged: (value) => setState(() => _addressId = value),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _daysController,
                      decoration: const InputDecoration(
                        labelText: 'Expires In Days',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validateDays,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Notes',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    if (commandState.hasError) ...[
                      const SizedBox(height: 14),
                      Text(
                        commandState.error.toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (commandState.valueOrNull != null) ...[
                      const SizedBox(height: 14),
                      GeneratedCodeResult(result: commandState.valueOrNull!),
                    ],
                  ],
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Unable to load addresses: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: commandState.isLoading
              ? null
              : () => Navigator.of(context).pop(commandState.valueOrNull),
          child: Text(commandState.valueOrNull == null ? 'Cancel' : 'Close'),
        ),
        FilledButton.icon(
          onPressed: commandState.isLoading ? null : _generate,
          icon: commandState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.password_outlined),
          label: const Text('Generate'),
        ),
      ],
    );
  }

  String? _selectedAddressLabel(List<ActivationCodeAddressOption> items) {
    final addressId = _addressId;
    if (addressId == null) {
      return null;
    }

    for (final item in items) {
      if (item.id == addressId) {
        return item.label;
      }
    }

    return addressId;
  }

  String? _validateDays(String? value) {
    final days = int.tryParse(value?.trim() ?? '');
    if (days == null || days < 1 || days > 365) {
      return 'Use 1 to 365 days';
    }
    return null;
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final days = int.parse(_daysController.text.trim());
    await ref.read(activationCodeCommandProvider.notifier).generateCode(
          GenerateActivationCodeInput(
            addressId: _addressId!,
            expiresAt: DateTime.now().toUtc().add(Duration(days: days)),
            reason: _reasonController.text,
          ),
        );
  }
}
