import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class ResidentSignInPage extends ConsumerStatefulWidget {
  const ResidentSignInPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  ConsumerState<ResidentSignInPage> createState() => _ResidentSignInPageState();
}

class _ResidentSignInPageState extends ConsumerState<ResidentSignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentPortalAuthControllerProvider);
    final user = ref.watch(currentUserProvider);

    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/portal/${widget.tenantCode}/activation-code');
        }
      });
    }

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: 'Resident sign in',
      subtitle: 'Sign in after you verify your email so you can enter your activation code.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _signIn(),
            decoration: const InputDecoration(labelText: 'Password'),
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
            onPressed: state.isLoading ? null : _signIn,
            child: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/portal/${widget.tenantCode}/register'),
            child: const Text('Need an account? Register here'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    final success = await ref.read(residentPortalAuthControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (success && mounted) {
      context.go('/portal/${widget.tenantCode}/activation-code');
    }
  }
}
