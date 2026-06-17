import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class EmailVerificationPendingPage extends ConsumerWidget {
  const EmailVerificationPendingPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registration = ref.watch(residentRegistrationStateProvider);

    return ResidentPortalScaffold(
      tenantCode: tenantCode,
      title: 'Check your email',
      subtitle:
          'We sent a verification link to ${registration?.email ?? 'your email address'}. After verifying your email, sign in and enter your activation code.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 56),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/portal/$tenantCode/sign-in'),
            child: const Text('Continue to sign in'),
          ),
        ],
      ),
    );
  }
}
