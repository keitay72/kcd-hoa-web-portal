// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

enum _ResidentEmailConfirmationState {
  processing,
  expired,
  invalid,
  error,
}

class ResidentEmailConfirmationPage extends ConsumerStatefulWidget {
  const ResidentEmailConfirmationPage({
    required this.tenantCode,
    super.key,
  });

  const ResidentEmailConfirmationPage.generic({super.key}) : tenantCode = null;

  final String? tenantCode;

  @override
  ConsumerState<ResidentEmailConfirmationPage> createState() =>
      _ResidentEmailConfirmationPageState();
}

class _ResidentEmailConfirmationPageState
    extends ConsumerState<ResidentEmailConfirmationPage> {
  _ResidentEmailConfirmationState _state =
      _ResidentEmailConfirmationState.processing;
  String? _message;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _completeVerification());
  }

  @override
  Widget build(BuildContext context) {
    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: _title,
      subtitle: _message ?? _subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_state == _ResidentEmailConfirmationState.processing) ...[
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            Icon(
              _icon,
              size: 56,
              color: _iconColor(context),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(_signInPath),
              child: const Text('Back to sign in'),
            ),
          ],
        ],
      ),
    );
  }

  String get _title {
    return switch (_state) {
      _ResidentEmailConfirmationState.processing => 'Confirming your email',
      _ResidentEmailConfirmationState.expired => 'Verification link expired',
      _ResidentEmailConfirmationState.invalid => 'Verification link invalid',
      _ResidentEmailConfirmationState.error => 'We hit a snag',
    };
  }

  String get _subtitle {
    return switch (_state) {
      _ResidentEmailConfirmationState.processing =>
        'Please give us a moment while we confirm your email and prepare your resident portal access.',
      _ResidentEmailConfirmationState.expired =>
        'That email verification link has expired. Head back to sign in or register again to request a fresh email.',
      _ResidentEmailConfirmationState.invalid =>
        'This verification link is no longer valid. Please request a new verification email and try again.',
      _ResidentEmailConfirmationState.error =>
        'We could not finish verifying your email right now. Please try again from the newest email or return to sign in.',
    };
  }

  IconData get _icon {
    return switch (_state) {
      _ResidentEmailConfirmationState.processing =>
        Icons.mark_email_read_outlined,
      _ResidentEmailConfirmationState.expired => Icons.schedule_outlined,
      _ResidentEmailConfirmationState.invalid => Icons.link_off_outlined,
      _ResidentEmailConfirmationState.error => Icons.error_outline,
    };
  }

  Color _iconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (_state) {
      _ResidentEmailConfirmationState.expired => colorScheme.tertiary,
      _ResidentEmailConfirmationState.invalid => colorScheme.error,
      _ResidentEmailConfirmationState.error => colorScheme.error,
      _ResidentEmailConfirmationState.processing => colorScheme.primary,
    };
  }

  Future<void> _completeVerification() async {
    try {
      final repository = ref.read(residentPortalAuthRepositoryProvider);
      await repository.completeEmailVerificationFromUri(Uri.base);
      final tenantCode = widget.tenantCode ??
          await repository.resolveTenantCodeForCurrentResident();
      html.window.localStorage.remove('resident_pending_tenant_code');
      html.window.localStorage.remove('resident_email_callback_payload');
      _clearSensitiveUrl(tenantCode);
      if (!mounted) return;
      context.go('/portal/$tenantCode/success');
    } catch (error) {
      html.window.localStorage.remove('resident_pending_tenant_code');
      html.window.localStorage.remove('resident_email_callback_payload');
      _clearSensitiveUrl(widget.tenantCode);
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      final normalized = message.toLowerCase();

      if (normalized.contains('otp_expired') ||
          normalized.contains('expired') ||
          normalized.contains('has expired')) {
        setState(() {
          _state = _ResidentEmailConfirmationState.expired;
          _message =
              'That email verification link has expired. Please return to sign in and request a new verification email.';
        });
        return;
      }

      if (normalized.contains('invalid') ||
          normalized.contains('missing required information') ||
          normalized.contains('missing required')) {
        setState(() {
          _state = _ResidentEmailConfirmationState.invalid;
          _message =
              'This verification link is no longer valid. Please request a new email and try again.';
        });
        return;
      }

      setState(() {
        _state = _ResidentEmailConfirmationState.error;
        _message = message.isEmpty
            ? 'We could not finish verifying your email right now. Please try again from the newest verification email.'
            : message;
      });
    }
  }

  String get _signInPath {
    final tenantCode = widget.tenantCode;
    return tenantCode == null ? '/sign-in' : '/portal/$tenantCode/sign-in';
  }

  void _clearSensitiveUrl(String? tenantCode) {
    final cleanedPath = tenantCode == null
        ? '/#/portal/confirm-email'
        : '/#/portal/$tenantCode/confirm-email';
    html.window.history.replaceState(null, '', cleanedPath);
  }
}
