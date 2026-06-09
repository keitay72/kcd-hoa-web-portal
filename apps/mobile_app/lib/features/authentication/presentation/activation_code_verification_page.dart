import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'resident_auth_providers.dart';

class ActivationCodeVerificationPage extends ConsumerStatefulWidget {
  const ActivationCodeVerificationPage({super.key});

  @override
  ConsumerState<ActivationCodeVerificationPage> createState() =>
      _ActivationCodeVerificationPageState();
}

class _ActivationCodeVerificationPageState
    extends ConsumerState<ActivationCodeVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentAuthControllerProvider);
    final registration = ref.watch(residentRegistrationStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activation Code')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter Activation Code',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        registration == null
                            ? 'Enter the activation code provided for your HOA address.'
                            : '${registration.address.singleLine}\n${registration.address.hoaLabel}',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Activation Code'),
                        validator: _required,
                      ),
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
                            : const Text('Verify Code'),
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
    final success = await ref
        .read(residentAuthControllerProvider.notifier)
        .verifyActivationCode(_codeController.text);
    if (success && mounted) context.go('/registration-success');
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}
