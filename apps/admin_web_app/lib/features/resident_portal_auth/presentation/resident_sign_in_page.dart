// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  String? _postSignInError;
  String? _postSignInStatus;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentPortalAuthControllerProvider);

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: 'Customer sign in',
      subtitle: null,
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
              _errorText(state.error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_postSignInError != null) ...[
            const SizedBox(height: 12),
            Text(
              _postSignInError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_postSignInStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _postSignInStatus!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
            onPressed: () =>
                context.go('/portal/${widget.tenantCode}/register'),
            child: const Text('Need an account? Register here'),
          ),
          TextButton(
            onPressed: () =>
                context.go('/portal/${widget.tenantCode}/forgot-password'),
            child: const Text('Forgot password?'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _postSignInError = null;
      _postSignInStatus = 'Signing in...';
    });
    final success =
        await ref.read(residentPortalAuthControllerProvider.notifier).signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
    if (!mounted) return;
    if (!success) {
      setState(() => _postSignInStatus = null);
      return;
    }

    setState(() => _postSignInStatus = 'Checking customer access...');

    final repository = ref.read(residentPortalAuthRepositoryProvider);
    final String? serviceLocationId;
    try {
      serviceLocationId = await repository
          .currentUserCustomerServiceLocationId()
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _postSignInStatus = null;
        _postSignInError = 'Signed in, but customer access check failed: '
            '${_errorText(error)}';
      });
      return;
    }

    if (!mounted) return;
    if (serviceLocationId == null || serviceLocationId.isEmpty) {
      setState(() {
        _postSignInStatus = null;
        _postSignInError =
            'Signed in, but this account does not have verified customer access yet.';
      });
      return;
    }

    setState(() => _postSignInStatus = 'Opening customer portal...');
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
    _openResidentPortal();
  }

  void _openResidentPortal() {
    final target = '/portal/${widget.tenantCode}/home';
    html.window.localStorage['resident_last_tenant_code'] = widget.tenantCode;
    html.window.history.replaceState(
      null,
      'Customer Portal',
      '${html.window.location.origin}$target',
    );
    context.go(target);
  }

  String _errorText(Object? error) {
    final message =
        error?.toString().replaceFirst('Bad state: ', '').trim() ?? '';
    if (message.isEmpty) return 'Unable to sign in.';
    return message;
  }
}
