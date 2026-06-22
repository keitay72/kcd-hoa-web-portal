import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/admin_context.dart';
import '../../../core/rbac/rbac_providers.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../resident_portal_auth/presentation/resident_auth_providers.dart';
import '../../resident_portal_auth/presentation/resident_portal_labels.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({this.tenantCode, super.key});

  final String? tenantCode;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantCode = widget.tenantCode;
    final portalTitle = tenantCode == null
        ? 'Customer Portal'
        : customerPortalTitle(tenantCode);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  portalTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  tenantCode == null
                      ? 'Sign in to continue.'
                      : 'Sign in to continue to this customer portal.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
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
                if (tenantCode != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/portal/$tenantCode/register'),
                    child: const Text('Need an account? Register here'),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.go('/portal/$tenantCode/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await ref.read(supabaseClientProvider).auth.signInWithPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
      final userId = response.user?.id ??
          ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException('Unable to establish a signed-in session.');
      }

      ref.invalidate(authStateProvider);
      ref.invalidate(currentUserProvider);

      final route = await _postSignInRoute(userId);
      if (!mounted) return;
      context.go(route);
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } on StateError catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _postSignInRoute(String userId) async {
    final adminAccess =
        await ref.read(rbacServiceProvider).accessForUser(userId);
    if (adminAccess.hasAnyRole) {
      return _adminHomeRoute(adminAccess);
    }

    final tenantCode = widget.tenantCode ??
        await ref
            .read(residentPortalAuthRepositoryProvider)
            .resolveTenantCodeForCurrentResident();
    final serviceLocationId = await ref
        .read(residentPortalAuthRepositoryProvider)
        .currentUserCustomerServiceLocationId();
    if (serviceLocationId != null && serviceLocationId.isNotEmpty) {
      return '/portal/$tenantCode/home';
    }

    throw StateError(
      'This account does not have management access or verified customer access yet.',
    );
  }

  String _adminHomeRoute(AdminAccess access) {
    if (access.globalRoles.isNotEmpty) {
      setSelectedAdminContextId(ref, 'platform');
      return '/admin';
    }

    if (access.tenantRoles.isNotEmpty) {
      final tenantId = access.tenantRoles.first.tenantId;
      if (tenantId != null) {
        setSelectedAdminContextId(ref, 'tenant:$tenantId');
      }
      return '/admin/hoas';
    }

    if (access.hoaRoles.isNotEmpty) {
      final hoaId = access.hoaRoles.first.hoaId;
      if (hoaId != null) {
        setSelectedAdminContextId(ref, 'hoa:$hoaId');
      }
      if (!access.hasAnyRoleCode(const {'hoa_manager', 'hoa_board'})) {
        return '/admin/hoa/documents';
      }
      return '/admin/hoa';
    }

    return '/admin';
  }
}
