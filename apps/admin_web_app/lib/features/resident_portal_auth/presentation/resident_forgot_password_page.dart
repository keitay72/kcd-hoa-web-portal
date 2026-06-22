import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class ResidentForgotPasswordPage extends ConsumerStatefulWidget {
  const ResidentForgotPasswordPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  ConsumerState<ResidentForgotPasswordPage> createState() =>
      _ResidentForgotPasswordPageState();
}

class _ResidentForgotPasswordPageState
    extends ConsumerState<ResidentForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentPortalAuthControllerProvider);

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: _sent ? 'Check your email' : 'Reset your password',
      subtitle: _sent
          ? 'If that email has an account, we sent a secure password reset link.'
          : 'Enter the email address for your customer portal account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_sent) ...[
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _email,
              ),
              if (state.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText(state.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isLoading ? null : _sendResetEmail,
                child: state.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send reset link'),
              ),
            ] else ...[
              const Icon(Icons.mark_email_unread_outlined, size: 56),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    context.go('/portal/${widget.tenantCode}/sign-in'),
                child: const Text('Back to sign in'),
              ),
            ],
            if (!_sent) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    context.go('/portal/${widget.tenantCode}/sign-in'),
                child: const Text('Back to sign in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final sent = await ref
        .read(residentPortalAuthControllerProvider.notifier)
        .sendPasswordResetEmail(
          tenantCode: widget.tenantCode,
          email: _emailController.text,
        );
    if (sent && mounted) {
      setState(() => _sent = true);
    }
  }

  String? _email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Required';
    if (!input.contains('@') || !input.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String _errorText(Object? error) {
    final message =
        error?.toString().replaceFirst('Bad state: ', '').trim() ?? '';
    if (message.isEmpty) return 'Unable to send password reset email.';
    return message;
  }
}
