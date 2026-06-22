import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

class AdminResetPasswordPage extends ConsumerStatefulWidget {
  const AdminResetPasswordPage({super.key});

  @override
  ConsumerState<AdminResetPasswordPage> createState() =>
      _AdminResetPasswordPageState();
}

class _AdminResetPasswordPageState
    extends ConsumerState<AdminResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _preparedSession = false;
  bool _isLoading = false;
  bool _ready = false;
  bool _saved = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparedSession) return;
    _preparedSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareResetSession());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                    _saved ? 'Password updated' : 'Create a new password',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_saved) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Your password has been updated. You can now sign in.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_ready && !_saved && _message == null) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else if (!_ready && _message != null) ...[
                    Icon(
                      Icons.link_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: const Text('Request a new link'),
                    ),
                  ] else if (_saved) ...[
                    const Icon(Icons.verified_outlined, size: 56),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await ref.read(supabaseClientProvider).auth.signOut();
                        if (context.mounted) context.go('/sign-in');
                      },
                      child: const Text('Return to sign in'),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      validator: _password,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                      validator: _confirmPassword,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isLoading ? null : _savePassword,
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update password'),
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

  Future<void> _prepareResetSession() async {
    try {
      await _beginRecoverySession(Uri.base);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _message = _errorText(error);
      });
    }
  }

  Future<void> _beginRecoverySession(Uri uri) async {
    final client = ref.read(supabaseClientProvider);
    final params = _combinedParams(uri);
    final urlError = params['error_description'] ?? params['error'];
    if (urlError != null && urlError.trim().isNotEmpty) {
      throw StateError(urlError.trim());
    }

    final code = params['code'];
    final tokenHash = params['token_hash'];
    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (tokenHash != null && tokenHash.isNotEmpty) {
      await client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: type == 'recovery' ? OtpType.recovery : OtpType.email,
      );
      await _waitForAuthenticatedSession();
      return;
    }

    if (code != null && code.isNotEmpty) {
      await client.auth.exchangeCodeForSession(code);
      await _waitForAuthenticatedSession();
      return;
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
      await _waitForAuthenticatedSession();
      return;
    }

    if (client.auth.currentUser != null) return;

    throw StateError(
      'This password reset link is expired or has already been used. Please request a new reset email.',
    );
  }

  Future<void> _waitForAuthenticatedSession() async {
    final client = ref.read(supabaseClientProvider);
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (client.auth.currentUser != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Unable to establish a password reset session.');
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('profiles').update({
          'password_set_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'active',
        }).eq('id', user.id);
      }
      if (!mounted) return;
      setState(() => _saved = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _errorText(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _password(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _confirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Map<String, String> _combinedParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(
        fragment.startsWith('#') ? fragment.substring(1) : fragment,
      );
      params.addAll(fragmentParams);
    }
    return params;
  }

  String _errorText(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    if (message.isEmpty) {
      return 'This password reset link is expired or has already been used.';
    }
    return message;
  }
}
