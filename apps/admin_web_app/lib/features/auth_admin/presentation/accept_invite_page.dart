// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';

enum _InviteAcceptState {
  processing,
  passwordSetup,
  success,
  expired,
  invalid,
  error,
}

class AcceptInvitePage extends ConsumerStatefulWidget {
  const AcceptInvitePage({super.key});

  @override
  ConsumerState<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends ConsumerState<AcceptInvitePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _InviteAcceptState _state = _InviteAcceptState.processing;
  String? _message;
  bool _started = false;
  bool _isSavingPassword = false;
  bool _obscurePassword = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptInvite());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final view = _viewForState(colorScheme);

    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 520;
    final cardMargin = isCompact ? 16.0 : 24.0;
    final cardPadding = isCompact ? 20.0 : 28.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: cardMargin,
                right: cardMargin,
                top: cardMargin,
                bottom: MediaQuery.viewInsetsOf(context).bottom + cardMargin,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (cardMargin * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CircleAvatar(
                              radius: isCompact ? 26 : 30,
                              backgroundColor: view.backgroundColor,
                              child: Icon(
                                view.icon,
                                color: view.iconColor,
                                size: isCompact ? 28 : 32,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              view.title,
                              textAlign: TextAlign.center,
                              style: (isCompact
                                      ? Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                      : Theme.of(context)
                                          .textTheme
                                          .headlineMedium)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _message ?? view.message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            if (_state == _InviteAcceptState.processing)
                              const Center(child: CircularProgressIndicator())
                            else if (_state == _InviteAcceptState.passwordSetup)
                              _PasswordSetupForm(
                                formKey: _formKey,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                obscurePassword: _obscurePassword,
                                isSaving: _isSavingPassword,
                                onToggleObscure: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                                onSubmit: _savePassword,
                              )
                            else ...[
                              FilledButton.icon(
                                onPressed: () {
                                  if (_state == _InviteAcceptState.success) {
                                    context.go('/admin');
                                    return;
                                  }

                                  _leaveInviteRoute();
                                },
                                icon: Icon(
                                  _state == _InviteAcceptState.success
                                      ? Icons.arrow_forward
                                      : Icons.login,
                                ),
                                label: Text(
                                  _state == _InviteAcceptState.success
                                      ? 'Continue to Admin Portal'
                                      : 'Back to Sign In',
                                ),
                              ),
                              if (_state != _InviteAcceptState.success) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _leaveInviteRoute,
                                  icon:
                                      const Icon(Icons.support_agent_outlined),
                                  label: const Text(
                                      'Ask an admin to resend the invite'),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _acceptInvite() async {
    final client = ref.read(supabaseClientProvider);
    final uri = Uri.base;
    final params = _combinedParams(uri);

    _clearSensitiveUrl();

    final urlError = params['error_description'] ?? params['error'];
    if (urlError != null && urlError.trim().isNotEmpty) {
      _showFailure(urlError);
      return;
    }

    final code = params['code'];
    final tokenHash = params['token_hash'];
    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    final hasInvitePayload = (tokenHash != null && tokenHash.isNotEmpty) ||
        (code != null && code.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
    if (!hasInvitePayload) {
      _leaveInviteRoute();
      return;
    }

    try {
      await client.auth.signOut();

      if (tokenHash != null && tokenHash.isNotEmpty) {
        if (type != null && type != 'invite') {
          _setState(
            _InviteAcceptState.invalid,
            'This invite link is not valid for admin access.',
          );
          return;
        }

        await client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: OtpType.invite,
        );
        await _markInviteAccepted();
        _setPasswordSetupState();
        return;
      }

      if (code != null && code.isNotEmpty) {
        await client.auth.exchangeCodeForSession(code);
        await _markInviteAccepted();
        _setPasswordSetupState();
        return;
      }

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await client.auth.setSession(
          refreshToken,
          accessToken: accessToken,
        );
        await _markInviteAccepted();
        _setPasswordSetupState();
        return;
      }

      _setState(
        _InviteAcceptState.invalid,
        'This invite link is missing required information. Please ask your administrator to resend the invitation.',
      );
    } on AuthException catch (error) {
      _showFailure(error.message);
    } catch (_) {
      _setState(
        _InviteAcceptState.error,
        'We could not accept this invitation. Please ask your administrator to resend it.',
      );
    }
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSavingPassword = true;
      _message = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await client.from('profiles').update({
        'password_set_at': now,
        'status': 'active',
        'updated_at': now,
      }).eq('id', client.auth.currentUser!.id);
      ref.invalidate(currentAdminProfileProvider);
      await _markInviteAccepted();
      _setState(
        _InviteAcceptState.success,
        'Your password has been saved. You can continue to the admin portal.',
      );
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } catch (_) {
      setState(() {
        _message = 'We could not save your password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _markInviteAccepted() async {
    try {
      await ref.read(supabaseClientProvider).rpc(
            'mark_current_user_admin_invite_accepted',
          );
    } catch (_) {
      // Older databases may not have this helper yet. The admin user list can
      // still reconcile accepted invites after the migration is deployed.
    }
  }

  void _setPasswordSetupState() {
    _setState(
      _InviteAcceptState.passwordSetup,
      'Create a password to finish setting up your admin account.',
    );
  }

  void _showFailure(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('expired') ||
        normalized.contains('invalid') ||
        normalized.contains('otp')) {
      _setState(
        _InviteAcceptState.expired,
        'This invitation link is no longer valid or has already been used. Please ask your administrator to resend the invite.',
      );
      return;
    }

    _setState(_InviteAcceptState.error, message);
  }

  void _setState(_InviteAcceptState state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  Map<String, String> _combinedParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final fragment = uri.fragment;
    if (fragment.isEmpty) return params;

    var normalizedFragment = fragment;
    final hashQueryStart = normalizedFragment.indexOf('?');
    if (hashQueryStart >= 0) {
      normalizedFragment = normalizedFragment.substring(hashQueryStart + 1);
    } else if (normalizedFragment.startsWith('?')) {
      normalizedFragment = normalizedFragment.substring(1);
    }

    if (normalizedFragment.isEmpty || !normalizedFragment.contains('=')) {
      return params;
    }

    try {
      params.addAll(Uri.splitQueryString(normalizedFragment));
    } on FormatException {
      // Some browsers/extensions can add non-query fragments. Ignore those.
    }

    return params;
  }

  void _clearSensitiveUrl() {
    html.window.history
        .replaceState(null, 'Accept Invitation', '/accept-invite');
  }

  void _leaveInviteRoute() {
    final client = ref.read(supabaseClientProvider);
    final storedContext = html.window.localStorage['selected_admin_context_id'];
    final target = client.auth.currentUser != null &&
            (storedContext?.startsWith('hoa:') ?? false)
        ? '/admin/hoa/documents'
        : '/sign-in';

    html.window.history.replaceState(
      null,
      'Customer Portal Admin',
      '${html.window.location.origin}$target',
    );

    if (mounted) {
      context.go(target);
    }
  }

  _InviteView _viewForState(ColorScheme colorScheme) {
    return switch (_state) {
      _InviteAcceptState.processing => _InviteView(
          icon: Icons.mark_email_read_outlined,
          iconColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          title: 'Accepting invitation',
          message: 'Please wait while we verify your invitation.',
        ),
      _InviteAcceptState.passwordSetup => _InviteView(
          icon: Icons.lock_reset_outlined,
          iconColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          title: 'Create your password',
          message: 'Create a password to finish setting up your admin account.',
        ),
      _InviteAcceptState.success => _InviteView(
          icon: Icons.check_circle_outline,
          iconColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          title: 'Account ready',
          message: 'Your invitation has been accepted.',
        ),
      _InviteAcceptState.expired => _InviteView(
          icon: Icons.schedule_outlined,
          iconColor: colorScheme.error,
          backgroundColor: colorScheme.errorContainer,
          title: 'Invitation expired',
          message: 'This invitation is expired or has already been used.',
        ),
      _InviteAcceptState.invalid => _InviteView(
          icon: Icons.link_off_outlined,
          iconColor: colorScheme.error,
          backgroundColor: colorScheme.errorContainer,
          title: 'Invalid invitation',
          message: 'This invitation link is invalid.',
        ),
      _InviteAcceptState.error => _InviteView(
          icon: Icons.error_outline,
          iconColor: colorScheme.error,
          backgroundColor: colorScheme.errorContainer,
          title: 'Unable to accept invitation',
          message: 'Something went wrong while accepting this invitation.',
        ),
    };
  }
}

class _PasswordSetupForm extends StatelessWidget {
  const _PasswordSetupForm({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.isSaving,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool isSaving;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              helperText: 'Use at least 8 characters.',
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.length < 8) {
                return 'Password must be at least 8 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => isSaving ? null : onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value != passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isSaving ? null : onSubmit,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(isSaving ? 'Saving password...' : 'Save password'),
          ),
        ],
      ),
    );
  }
}

class _InviteView {
  const _InviteView({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String message;
}
