import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/resident_address.dart';
import 'resident_auth_providers.dart';

class AddressVerificationPage extends ConsumerStatefulWidget {
  const AddressVerificationPage({super.key});

  @override
  ConsumerState<AddressVerificationPage> createState() => _AddressVerificationPageState();
}

class _AddressVerificationPageState extends ConsumerState<AddressVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'MO');
  final _postalCodeController = TextEditingController();

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentAuthControllerProvider);
    final verifiedAddress = ref.watch(verifiedAddressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify HOA Address')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter your HOA service address. The HOA is assigned from the verified address.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _line1Controller,
                        decoration: const InputDecoration(labelText: 'Street Address'),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _line2Controller,
                        decoration: const InputDecoration(labelText: 'Unit / Apt'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(labelText: 'State'),
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(labelText: 'ZIP Code'),
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      if (verifiedAddress != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Verified: ${verifiedAddress.singleLine}\n${verifiedAddress.hoaLabel}',
                            ),
                          ),
                        ),
                      ],
                      if (state.hasError) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error.toString(),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: state.isLoading ? null : _submit,
                        child: state.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Verify Address'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(residentAuthControllerProvider.notifier).verifyAddress(
          ResidentAddressInput(
            line1: _line1Controller.text,
            line2: _line2Controller.text,
            city: _cityController.text,
            state: _stateController.text,
            postalCode: _postalCodeController.text,
          ),
        );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}
