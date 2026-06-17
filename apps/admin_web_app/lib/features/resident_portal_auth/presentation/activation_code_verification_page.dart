import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class ActivationCodeVerificationPage extends ConsumerStatefulWidget {
  const ActivationCodeVerificationPage({required this.tenantCode, super.key});

  final String tenantCode;

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
    final state = ref.watch(residentPortalAuthControllerProvider);
    final registration = ref.watch(residentRegistrationStateProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/portal/${widget.tenantCode}/sign-in');
        }
      });
    }

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: 'Enter your activation code',
      subtitle: registration == null
          ? 'Use the activation code provided for your HOA service address.'
          : '${registration.address.singleLine}\n${registration.address.hoaLabel}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify code'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(residentPortalAuthControllerProvider.notifier)
        .verifyActivationCode(_codeController.text);
    if (success && mounted) {
      context.go('/portal/${widget.tenantCode}/success');
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}
