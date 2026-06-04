import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase/supabase_provider.dart';
import '../features/auth_admin/presentation/sign_in_page.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/admin',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isSignIn = state.uri.path == '/sign-in';

      if (user == null) {
        return isSignIn ? null : '/sign-in';
      }

      if (isSignIn) {
        return '/admin';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'adminHome',
        builder: (context, state) => const AdminHomePage(),
      ),
    ],
  );
});

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KC Disposal Admin'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('Signed in as ${user?.email ?? user?.id ?? 'admin'}'),
            const SizedBox(height: 24),
            const Text('Supabase connection is active.'),
          ],
        ),
      ),
    );
  }
}
