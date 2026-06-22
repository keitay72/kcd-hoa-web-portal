import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';

class AdminForgotPasswordPage extends ConsumerStatefulWidget {
  const AdminForgotPasswordPage({super.key});

  @override
  ConsumerState<AdminForgotPasswordPage> createState() =>
      _AdminForgotPasswordPageState();
}

class _AdminForgotPasswordPageState
    extends ConsumerState<AdminForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _sent ? 'Check your email' : 'Reset your password',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sent
                        ? 'If that email has an account, we sent a secure password reset link.'
                        : 'Enter the email address for your portal account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!_sent) ...[
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _email,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send reset link'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/sign-in'),
                      child: const Text('Back to sign in'),
                    ),
                  ] else ...[
                    const Icon(Icons.mark_email_unread_outlined, size: 56),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/sign-in'),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(
            _emailController.text.trim(),
            redirectTo: '${Uri.base.origin}/reset-password',
          );
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorText(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  String _errorText(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    if (message.isEmpty) return 'Unable to send password reset email.';
    return message;
  }
}
