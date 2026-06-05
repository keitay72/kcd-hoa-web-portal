import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase/supabase_provider.dart';
import '../features/address_registry/presentation/address_detail_page.dart';
import '../features/address_registry/presentation/address_list_page.dart';
import '../features/activation_codes/presentation/activation_code_detail_page.dart';
import '../features/activation_codes/presentation/activation_code_list_page.dart';
import '../features/auth_admin/presentation/sign_in_page.dart';
import '../features/hoa_management/presentation/hoa_detail_page.dart';
import '../features/hoa_management/presentation/hoa_list_page.dart';

final currentAdminRoleProvider = FutureProvider.autoDispose<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return 'Signed out';
  }

  final rows = await ref
      .watch(supabaseClientProvider)
      .from('user_platform_roles')
      .select('roles(code, name)')
      .eq('user_id', user.id);

  if (rows.isEmpty) {
    return 'No role assigned';
  }

  final roleNames = rows.map((row) {
    final role = row['roles'] as Map<String, dynamic>?;
    return role?['name'] as String? ?? role?['code'] as String? ?? 'Unknown role';
  }).toList()
    ..sort();

  return roleNames.join(', ');
});

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
      ShellRoute(
        builder: (context, state, child) {
          return AdminNavigationShell(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin',
            name: 'adminHome',
            builder: (context, state) => const AdminHomePage(),
          ),
          GoRoute(
            path: '/admin/hoas',
            name: 'hoaList',
            builder: (context, state) => const HoaListPage(),
          ),
          GoRoute(
            path: '/admin/hoas/:hoaId',
            name: 'hoaDetail',
            builder: (context, state) => HoaDetailPage(
              hoaId: state.pathParameters['hoaId']!,
            ),
          ),
          GoRoute(
            path: '/admin/addresses',
            name: 'addressList',
            builder: (context, state) => const AddressListPage(),
          ),
          GoRoute(
            path: '/admin/addresses/:addressId',
            name: 'addressDetail',
            builder: (context, state) => AddressDetailPage(
              addressId: state.pathParameters['addressId']!,
            ),
          ),
          GoRoute(
            path: '/admin/activation-codes',
            name: 'activationCodeList',
            builder: (context, state) => const ActivationCodeListPage(),
          ),
          GoRoute(
            path: '/admin/activation-codes/:activationCodeId',
            name: 'activationCodeDetail',
            builder: (context, state) => ActivationCodeDetailPage(
              activationCodeId: state.pathParameters['activationCodeId']!,
            ),
          ),
          GoRoute(
            path: '/admin/resident-verification',
            name: 'residentVerification',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Resident Verification',
              description: 'Resident verification management will be implemented next.',
            ),
          ),
          GoRoute(
            path: '/admin/announcements',
            name: 'announcements',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Announcements',
              description: 'Announcement CMS will be implemented next.',
            ),
          ),
          GoRoute(
            path: '/admin/documents',
            name: 'documents',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Documents',
              description: 'Document CMS will be implemented next.',
            ),
          ),
          GoRoute(
            path: '/admin/service-schedules',
            name: 'serviceSchedules',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Service Schedules',
              description: 'Service schedule management will be implemented next.',
            ),
          ),
          GoRoute(
            path: '/admin/tickets',
            name: 'tickets',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Tickets',
              description: 'Ticket operations will be implemented next.',
            ),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            name: 'auditLogs',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Audit Logs',
              description: 'Audit log viewer will be implemented next.',
            ),
          ),
        ],
      ),
    ],
  );
});

class AdminNavigationShell extends ConsumerStatefulWidget {
  const AdminNavigationShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<AdminNavigationShell> createState() => _AdminNavigationShellState();
}

class _AdminNavigationShellState extends ConsumerState<AdminNavigationShell> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final nav = _AdminSidebar(
      currentPath: widget.currentPath,
      isCollapsed: isCompact ? false : _isCollapsed,
      onToggleCollapsed: isCompact
          ? null
          : () => setState(() => _isCollapsed = !_isCollapsed),
    );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('KC Disposal Admin'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: Drawer(child: nav),
        body: widget.child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          nav,
          const VerticalDivider(width: 1),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await ref.read(supabaseClientProvider).auth.signOut();
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.currentPath,
    required this.isCollapsed,
    required this.onToggleCollapsed,
  });

  final String currentPath;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;

  static const _items = [
    _AdminNavItem(
      label: 'Dashboard',
      path: '/admin',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin'],
      exact: true,
    ),
    _AdminNavItem(
      label: 'HOA Management',
      path: '/admin/hoas',
      icon: Icons.domain_outlined,
      activePrefixes: ['/admin/hoas'],
    ),
    _AdminNavItem(
      label: 'Address Registry',
      path: '/admin/addresses',
      icon: Icons.location_on_outlined,
      activePrefixes: ['/admin/addresses'],
    ),
    _AdminNavItem(
      label: 'Activation Codes',
      path: '/admin/activation-codes',
      icon: Icons.password_outlined,
      activePrefixes: ['/admin/activation-codes'],
    ),
    _AdminNavItem(
      label: 'Resident Verification',
      path: '/admin/resident-verification',
      icon: Icons.verified_user_outlined,
      activePrefixes: ['/admin/resident-verification'],
    ),
    _AdminNavItem(
      label: 'Announcements',
      path: '/admin/announcements',
      icon: Icons.campaign_outlined,
      activePrefixes: ['/admin/announcements'],
    ),
    _AdminNavItem(
      label: 'Documents',
      path: '/admin/documents',
      icon: Icons.description_outlined,
      activePrefixes: ['/admin/documents'],
    ),
    _AdminNavItem(
      label: 'Service Schedules',
      path: '/admin/service-schedules',
      icon: Icons.event_repeat_outlined,
      activePrefixes: ['/admin/service-schedules'],
    ),
    _AdminNavItem(
      label: 'Tickets',
      path: '/admin/tickets',
      icon: Icons.confirmation_number_outlined,
      activePrefixes: ['/admin/tickets'],
    ),
    _AdminNavItem(
      label: 'Audit Logs',
      path: '/admin/audit-logs',
      icon: Icons.fact_check_outlined,
      activePrefixes: ['/admin/audit-logs'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentAdminRoleProvider);
    final width = isCollapsed ? 84.0 : 292.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.delete_outline),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KC Disposal',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text('Admin Portal'),
                        ],
                      ),
                    ),
                  ],
                  if (onToggleCollapsed != null)
                    IconButton(
                      tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                      onPressed: onToggleCollapsed,
                      icon: Icon(
                        isCollapsed
                            ? Icons.keyboard_double_arrow_right
                            : Icons.keyboard_double_arrow_left,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isActive = item.isActive(currentPath);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: isCollapsed ? item.label : '',
                      child: Material(
                        color: isActive
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.go(item.path),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCollapsed ? 14 : 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: isCollapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : null,
                                ),
                                if (!isCollapsed) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontWeight: isActive
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isActive
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _AdminUserPanel(
                email: user?.email ?? user?.id ?? 'Unknown user',
                role: role.when(
                  data: (value) => value,
                  loading: () => 'Loading role...',
                  error: (_, __) => 'Role unavailable',
                ),
                isCollapsed: isCollapsed,
                onSignOut: () async {
                  await ref.read(supabaseClientProvider).auth.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserPanel extends StatelessWidget {
  const _AdminUserPanel({
    required this.email,
    required this.role,
    required this.isCollapsed,
    required this.onSignOut,
  });

  final String email;
  final String role;
  final bool isCollapsed;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Column(
        children: [
          Tooltip(
            message: '$email\n$role',
            child: const CircleAvatar(child: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 8),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem {
  const _AdminNavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.activePrefixes,
    this.exact = false,
  });

  final String label;
  final String path;
  final IconData icon;
  final List<String> activePrefixes;
  final bool exact;

  bool isActive(String currentPath) {
    if (exact) {
      return currentPath == path;
    }

    return activePrefixes.any((prefix) => currentPath.startsWith(prefix));
  }
}

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentAdminRoleProvider);

    return Padding(
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
          const SizedBox(height: 4),
          Text(
            'Role: ${role.valueOrNull ?? 'Loading role...'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const Text('Supabase connection is active.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/admin/hoas'),
                icon: const Icon(Icons.domain_outlined),
                label: const Text('Manage HOAs'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/admin/addresses'),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Address Registry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminComingSoonPage extends StatelessWidget {
  const AdminComingSoonPage({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(description),
            ],
          ),
        ),
      ),
    );
  }
}
