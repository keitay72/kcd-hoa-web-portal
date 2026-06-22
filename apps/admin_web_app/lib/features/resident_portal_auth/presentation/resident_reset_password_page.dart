// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class ResidentResetPasswordPage extends ConsumerStatefulWidget {
  const ResidentResetPasswordPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  ConsumerState<ResidentResetPasswordPage> createState() =>
      _ResidentResetPasswordPageState();
}

class _ResidentResetPasswordPageState
    extends ConsumerState<ResidentResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _preparedSession = false;
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
    final state = ref.watch(residentPortalAuthControllerProvider);

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: _saved ? 'Password updated' : 'Create a new password',
      subtitle: _saved
          ? 'Your password has been updated. You can now sign in.'
          : null,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    context.go('/portal/${widget.tenantCode}/forgot-password'),
                child: const Text('Request a new link'),
              ),
            ] else if (_saved) ...[
              const Icon(Icons.verified_outlined, size: 56),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(residentPortalAuthRepositoryProvider)
                      .signOut();
                  if (context.mounted) {
                    context.go('/portal/${widget.tenantCode}/sign-in');
                  }
                },
                child: const Text('Return to sign in'),
              ),
            ] else ...[
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password'),
                validator: _password,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
                validator: _confirmPassword,
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (state.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText(state.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isLoading ? null : _savePassword,
                child: state.isLoading
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
    );
  }

  Future<void> _prepareResetSession() async {
    final ready = await ref
        .read(residentPortalAuthControllerProvider.notifier)
        .beginPasswordRecovery(Uri.base);
    html.window.history.replaceState(
      null,
      'Customer Portal',
      '${html.window.location.origin}/portal/${widget.tenantCode}/reset-password',
    );
    if (!mounted) return;
    setState(() {
      _ready = ready;
      _message = ready ? null : 'This password reset link is no longer valid.';
    });
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await ref
        .read(residentPortalAuthControllerProvider.notifier)
        .updatePassword(_passwordController.text);
    if (saved && mounted) {
      setState(() {
        _saved = true;
        _message = null;
      });
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

  String _errorText(Object? error) {
    final message =
        error?.toString().replaceFirst('Bad state: ', '').trim() ?? '';
    if (message.isEmpty) return 'Unable to update password.';
    return message;
  }
}
