import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import 'resident_portal_scaffold.dart';

class RegistrationSuccessPage extends ConsumerWidget {
  const RegistrationSuccessPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResidentPortalScaffold(
      tenantCode: tenantCode,
      title: 'Registration complete',
      subtitle:
          'Your email and service address have been verified. You can now sign in to access your customer portal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_outlined, size: 56),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              if (context.mounted) {
                context.go('/portal/$tenantCode/sign-in');
              }
            },
            child: const Text('Return to sign in'),
          ),
        ],
      ),
    );
  }
}
