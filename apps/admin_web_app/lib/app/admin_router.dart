import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/rbac/admin_access.dart';
import '../core/rbac/permission_rules.dart';
import '../core/rbac/protected_admin_page.dart';
import '../core/rbac/rbac_providers.dart';
import '../core/rbac/unauthorized_page.dart';
import '../core/supabase/supabase_provider.dart';
import '../features/address_registry/presentation/address_detail_page.dart';
import '../features/address_registry/presentation/address_list_page.dart';
import '../features/activation_codes/presentation/activation_code_detail_page.dart';
import '../features/activation_codes/presentation/activation_code_list_page.dart';
import '../features/announcements_cms/presentation/announcement_detail_page.dart';
import '../features/announcements_cms/presentation/announcement_list_page.dart';
import '../features/auth_admin/presentation/sign_in_page.dart';
import '../features/documents_cms/presentation/document_detail_page.dart';
import '../features/documents_cms/presentation/document_list_page.dart';
import '../features/hoa_management/presentation/hoa_detail_page.dart';
import '../features/hoa_management/presentation/hoa_list_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_announcements_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_documents_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_manager_dashboard_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_resident_list_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_service_schedules_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_tickets_page.dart';
import '../features/schedules_admin/presentation/service_schedule_detail_page.dart';
import '../features/schedules_admin/presentation/service_schedule_list_page.dart';
import '../features/ticket_operations/domain/ticket.dart';
import '../features/ticket_operations/presentation/ticket_dashboard_page.dart';
import '../features/ticket_operations/presentation/ticket_detail_page.dart';
import '../features/ticket_operations/presentation/ticket_list_page.dart';
import '../features/user_management/presentation/user_detail_page.dart';
import '../features/user_management/presentation/user_list_page.dart';
import '../features/verification_admin/presentation/resident_verification_detail_page.dart';
import '../features/verification_admin/presentation/resident_verification_list_page.dart';

final currentAdminRoleProvider = currentAdminRoleSummaryProvider;

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
            builder: (context, state) => const AdminHomePage().protectedBy(AdminPermissions.dashboard),
          ),
          GoRoute(
            path: '/admin/hoa',
            name: 'hoaManagerDashboard',
            builder: (context, state) => const HoaManagerDashboardPage().protectedBy(AdminPermissions.hoaScoped),
          ),
          GoRoute(
            path: '/admin/hoa/residents',
            name: 'hoaResidentList',
            builder: (context, state) => const HoaResidentListPage().protectedBy(AdminPermissions.hoaScoped),
          ),
          GoRoute(
            path: '/admin/hoa/documents',
            name: 'hoaDocuments',
            builder: (context, state) => const HoaDocumentsPage().protectedBy(AdminPermissions.hoaDocuments),
          ),
          GoRoute(
            path: '/admin/hoa/announcements',
            name: 'hoaAnnouncements',
            builder: (context, state) => const HoaAnnouncementsPage().protectedBy(AdminPermissions.hoaAnnouncements),
          ),
          GoRoute(
            path: '/admin/hoa/tickets',
            name: 'hoaTickets',
            builder: (context, state) => const HoaTicketsPage().protectedBy(AdminPermissions.hoaTickets),
          ),
          GoRoute(
            path: '/admin/hoa/service-schedules',
            name: 'hoaServiceSchedules',
            builder: (context, state) => const HoaServiceSchedulesPage().protectedBy(AdminPermissions.hoaSchedules),
          ),
          GoRoute(
            path: '/admin/hoas',
            name: 'hoaList',
            builder: (context, state) => const HoaListPage().protectedBy(AdminPermissions.hoaRead),
          ),
          GoRoute(
            path: '/admin/hoas/:hoaId',
            name: 'hoaDetail',
            builder: (context, state) => HoaDetailPage(
              hoaId: state.pathParameters['hoaId']!,
            ).protectedBy(AdminPermissions.hoaRead),
          ),
          GoRoute(
            path: '/admin/addresses',
            name: 'addressList',
            builder: (context, state) => const AddressListPage().protectedBy(AdminPermissions.addressRead),
          ),
          GoRoute(
            path: '/admin/addresses/:addressId',
            name: 'addressDetail',
            builder: (context, state) => AddressDetailPage(
              addressId: state.pathParameters['addressId']!,
            ).protectedBy(AdminPermissions.addressRead),
          ),
          GoRoute(
            path: '/admin/activation-codes',
            name: 'activationCodeList',
            builder: (context, state) => const ActivationCodeListPage().protectedBy(AdminPermissions.activationCodes),
          ),
          GoRoute(
            path: '/admin/activation-codes/:activationCodeId',
            name: 'activationCodeDetail',
            builder: (context, state) => ActivationCodeDetailPage(
              activationCodeId: state.pathParameters['activationCodeId']!,
            ).protectedBy(AdminPermissions.activationCodes),
          ),
          GoRoute(
            path: '/admin/resident-verification',
            name: 'residentVerificationList',
            builder: (context, state) => const ResidentVerificationListPage().protectedBy(AdminPermissions.verificationRead),
          ),
          GoRoute(
            path: '/admin/resident-verification/:verificationId',
            name: 'residentVerificationDetail',
            builder: (context, state) => ResidentVerificationDetailPage(
              verificationId: state.pathParameters['verificationId']!,
            ).protectedBy(AdminPermissions.verificationRead),
          ),
          GoRoute(
            path: '/admin/announcements',
            name: 'announcementList',
            builder: (context, state) => const AnnouncementListPage().protectedBy(AdminPermissions.announcementsRead),
          ),
          GoRoute(
            path: '/admin/announcements/:announcementId',
            name: 'announcementDetail',
            builder: (context, state) => AnnouncementDetailPage(
              announcementId: state.pathParameters['announcementId']!,
            ).protectedBy(AdminPermissions.announcementsRead),
          ),
          GoRoute(
            path: '/admin/documents',
            name: 'documentList',
            builder: (context, state) => const DocumentListPage().protectedBy(AdminPermissions.documentsRead),
          ),
          GoRoute(
            path: '/admin/documents/:documentId',
            name: 'documentDetail',
            builder: (context, state) => DocumentDetailPage(
              documentId: state.pathParameters['documentId']!,
            ).protectedBy(AdminPermissions.documentsRead),
          ),
          GoRoute(
            path: '/admin/service-schedules',
            name: 'serviceScheduleList',
            builder: (context, state) => const ServiceScheduleListPage().protectedBy(AdminPermissions.schedulesRead),
          ),
          GoRoute(
            path: '/admin/service-schedules/:scheduleId',
            name: 'serviceScheduleDetail',
            builder: (context, state) => ServiceScheduleDetailPage(
              scheduleId: state.pathParameters['scheduleId']!,
            ).protectedBy(AdminPermissions.schedulesRead),
          ),
          GoRoute(
            path: '/admin/tickets',
            name: 'ticketList',
            builder: (context, state) => const TicketListPage().protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/csr',
            name: 'ticketCsrDashboard',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.csr,
            ).protectedBy(AdminPermissions.ticketsUpdate),
          ),
          GoRoute(
            path: '/admin/tickets/dispatch',
            name: 'ticketDispatchDashboard',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.dispatch,
            ).protectedBy(AdminPermissions.ticketsUpdate),
          ),
          GoRoute(
            path: '/admin/tickets/urgent',
            name: 'ticketUrgentQueue',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.urgent,
            ).protectedBy(AdminPermissions.ticketsUpdate),
          ),
          GoRoute(
            path: '/admin/tickets/aging',
            name: 'ticketAgingQueue',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.aging,
            ).protectedBy(AdminPermissions.ticketsUpdate),
          ),
          GoRoute(
            path: '/admin/tickets/:ticketId',
            name: 'ticketDetail',
            builder: (context, state) => TicketDetailPage(
              ticketId: state.pathParameters['ticketId']!,
            ).protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/users',
            name: 'userList',
            builder: (context, state) => const UserListPage().protectedBy(AdminPermissions.rolesManage),
          ),
          GoRoute(
            path: '/admin/users/:userId',
            name: 'userDetail',
            builder: (context, state) => UserDetailPage(
              userId: state.pathParameters['userId']!,
            ).protectedBy(AdminPermissions.rolesManage),
          ),
          GoRoute(
            path: '/admin/unauthorized',
            name: 'unauthorized',
            builder: (context, state) => const UnauthorizedPage(),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            name: 'auditLogs',
            builder: (context, state) => const AdminComingSoonPage(
              title: 'Audit Logs',
              description: 'Audit log viewer will be implemented next.',
            ).protectedBy(AdminPermissions.auditRead),
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
      permissionRule: AdminPermissions.dashboard,
      path: '/admin',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin'],
      exact: true,
    ),
    _AdminNavItem(
      label: 'HOA Management',
      permissionRule: AdminPermissions.hoaRead,
      path: '/admin/hoas',
      icon: Icons.domain_outlined,
      activePrefixes: ['/admin/hoas'],
    ),
    _AdminNavItem(
      label: 'Address Registry',
      permissionRule: AdminPermissions.addressRead,
      path: '/admin/addresses',
      icon: Icons.location_on_outlined,
      activePrefixes: ['/admin/addresses'],
    ),
    _AdminNavItem(
      label: 'Activation Codes',
      permissionRule: AdminPermissions.activationCodes,
      path: '/admin/activation-codes',
      icon: Icons.password_outlined,
      activePrefixes: ['/admin/activation-codes'],
    ),
    _AdminNavItem(
      label: 'Resident Verification',
      permissionRule: AdminPermissions.verificationRead,
      path: '/admin/resident-verification',
      icon: Icons.verified_user_outlined,
      activePrefixes: ['/admin/resident-verification'],
    ),
    _AdminNavItem(
      label: 'Announcements',
      permissionRule: AdminPermissions.announcementsRead,
      path: '/admin/announcements',
      icon: Icons.campaign_outlined,
      activePrefixes: ['/admin/announcements'],
    ),
    _AdminNavItem(
      label: 'Documents',
      permissionRule: AdminPermissions.documentsRead,
      path: '/admin/documents',
      icon: Icons.description_outlined,
      activePrefixes: ['/admin/documents'],
    ),
    _AdminNavItem(
      label: 'Service Schedules',
      permissionRule: AdminPermissions.schedulesRead,
      path: '/admin/service-schedules',
      icon: Icons.event_repeat_outlined,
      activePrefixes: ['/admin/service-schedules'],
    ),
    _AdminNavItem(
      label: 'Tickets',
      permissionRule: AdminPermissions.ticketsRead,
      path: '/admin/tickets',
      icon: Icons.confirmation_number_outlined,
      activePrefixes: ['/admin/tickets'],
    ),
    _AdminNavItem(
      label: 'Users & Roles',
      permissionRule: AdminPermissions.rolesManage,
      path: '/admin/users',
      icon: Icons.manage_accounts_outlined,
      activePrefixes: ['/admin/users'],
    ),
    _AdminNavItem(
      label: 'Audit Logs',
      permissionRule: AdminPermissions.auditRead,
      path: '/admin/audit-logs',
      icon: Icons.fact_check_outlined,
      activePrefixes: ['/admin/audit-logs'],
    ),
  ];


  static const _hoaItems = [
    _AdminNavItem(
      label: 'HOA Dashboard',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin/hoa'],
      exact: true,
    ),
    _AdminNavItem(
      label: 'Residents',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa/residents',
      icon: Icons.people_outline,
      activePrefixes: ['/admin/hoa/residents'],
    ),
    _AdminNavItem(
      label: 'Documents',
      permissionRule: AdminPermissions.hoaDocuments,
      path: '/admin/hoa/documents',
      icon: Icons.description_outlined,
      activePrefixes: ['/admin/hoa/documents'],
    ),
    _AdminNavItem(
      label: 'Announcements',
      permissionRule: AdminPermissions.hoaAnnouncements,
      path: '/admin/hoa/announcements',
      icon: Icons.campaign_outlined,
      activePrefixes: ['/admin/hoa/announcements'],
    ),
    _AdminNavItem(
      label: 'Tickets',
      permissionRule: AdminPermissions.hoaTickets,
      path: '/admin/hoa/tickets',
      icon: Icons.confirmation_number_outlined,
      activePrefixes: ['/admin/hoa/tickets'],
    ),
    _AdminNavItem(
      label: 'Service Schedules',
      permissionRule: AdminPermissions.hoaSchedules,
      path: '/admin/hoa/service-schedules',
      icon: Icons.event_repeat_outlined,
      activePrefixes: ['/admin/hoa/service-schedules'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentAdminRoleProvider);
    final access = ref.watch(adminAccessProvider);
    final visibleItems = access.maybeWhen(
      data: (value) {
        final source = value.isHoaScopedOnly ? _hoaItems : _items;
        return source.where((item) => item.canShow(value)).toList();
      },
      orElse: () => [_items.first],
    );
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
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
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
    required this.permissionRule,
    required this.path,
    required this.icon,
    required this.activePrefixes,
    this.exact = false,
  });

  final String label;
  final AdminPermissionRule permissionRule;
  final String path;
  final IconData icon;
  final List<String> activePrefixes;
  final bool exact;

  bool canShow(AdminAccess access) {
    if (permissionRule.isOpen) return true;
    final hasPermissions = permissionRule.permissions.isEmpty ||
        access.canAny(permissionRule.permissions);
    final hasRoles = permissionRule.roleCodes.isEmpty ||
        access.hasAnyRoleCode(permissionRule.roleCodes);
    return hasPermissions && hasRoles;
  }

  bool isActive(String currentPath) {
    if (exact) {
      return currentPath == path;
    }

    return activePrefixes.any((prefix) => currentPath.startsWith(prefix));
  }
}

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});


  static const _hoaItems = [
    _AdminNavItem(
      label: 'HOA Dashboard',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin/hoa'],
      exact: true,
    ),
    _AdminNavItem(
      label: 'Residents',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa/residents',
      icon: Icons.people_outline,
      activePrefixes: ['/admin/hoa/residents'],
    ),
    _AdminNavItem(
      label: 'Documents',
      permissionRule: AdminPermissions.hoaDocuments,
      path: '/admin/hoa/documents',
      icon: Icons.description_outlined,
      activePrefixes: ['/admin/hoa/documents'],
    ),
    _AdminNavItem(
      label: 'Announcements',
      permissionRule: AdminPermissions.hoaAnnouncements,
      path: '/admin/hoa/announcements',
      icon: Icons.campaign_outlined,
      activePrefixes: ['/admin/hoa/announcements'],
    ),
    _AdminNavItem(
      label: 'Tickets',
      permissionRule: AdminPermissions.hoaTickets,
      path: '/admin/hoa/tickets',
      icon: Icons.confirmation_number_outlined,
      activePrefixes: ['/admin/hoa/tickets'],
    ),
    _AdminNavItem(
      label: 'Service Schedules',
      permissionRule: AdminPermissions.hoaSchedules,
      path: '/admin/hoa/service-schedules',
      icon: Icons.event_repeat_outlined,
      activePrefixes: ['/admin/hoa/service-schedules'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentAdminRoleProvider);
    final access = ref.watch(adminAccessProvider);

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
          access.when(
            data: (value) => _AdminQuickActions(access: value),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Unable to load permissions: $error'),
          ),
        ],
      ),
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions({required this.access});

  final AdminAccess access;

  @override
  Widget build(BuildContext context) {
    final actions = access.isHoaScopedOnly ? _hoaActions(context) : _platformActions(context);

    if (actions.isEmpty) {
      return const Text('No admin actions are currently available for this role.');
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions,
    );
  }

  List<Widget> _hoaActions(BuildContext context) {
    return [
      FilledButton.icon(
        onPressed: () => context.go('/admin/hoa'),
        icon: const Icon(Icons.dashboard_outlined),
        label: const Text('HOA Dashboard'),
      ),
      FilledButton.icon(
        onPressed: () => context.go('/admin/hoa/residents'),
        icon: const Icon(Icons.people_outline),
        label: const Text('Residents'),
      ),
      if (access.can('announcements.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/hoa/announcements'),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Announcements'),
        ),
      if (access.can('documents.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/hoa/documents'),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Documents'),
        ),
      if (access.can('tickets.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/hoa/tickets'),
          icon: const Icon(Icons.confirmation_number_outlined),
          label: const Text('Tickets'),
        ),
    ];
  }

  List<Widget> _platformActions(BuildContext context) {
    return [
      if (access.can('hoa.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/hoas'),
          icon: const Icon(Icons.domain_outlined),
          label: const Text('Manage HOAs'),
        ),
      if (access.can('addresses.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/addresses'),
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('Address Registry'),
        ),
      if (access.can('tickets.read'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/tickets'),
          icon: const Icon(Icons.confirmation_number_outlined),
          label: const Text('Ticket Operations'),
        ),
      if (access.can('tickets.update'))
        FilledButton.icon(
          onPressed: () => context.go('/admin/tickets/dispatch'),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Dispatch Queue'),
        ),
    ];
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
