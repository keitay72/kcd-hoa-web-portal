// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/dev/dev_security_bypass.dart';
import '../core/rbac/admin_access.dart';
import '../core/rbac/admin_context.dart';
import '../core/rbac/permission_rules.dart';
import '../core/rbac/protected_admin_page.dart';
import '../core/rbac/rbac_providers.dart';
import '../core/rbac/unauthorized_page.dart';
import '../core/subscriptions/protected_tenant_feature_page.dart';
import '../core/subscriptions/subscription_providers.dart';
import '../core/subscriptions/tenant_entitlements.dart';
import '../core/supabase/supabase_provider.dart';
import '../features/analytics_dashboard/presentation/analytics_dashboard_page.dart';
import '../features/address_registry/presentation/address_detail_page.dart';
import '../features/address_registry/presentation/address_list_page.dart';
import '../features/activation_codes/presentation/activation_code_detail_page.dart';
import '../features/activation_codes/presentation/activation_code_list_page.dart';
import '../features/announcements_cms/presentation/announcement_detail_page.dart';
import '../features/announcements_cms/presentation/announcement_list_page.dart';
import '../features/audit_logs/presentation/audit_log_list_page.dart';
import '../features/auth_admin/presentation/accept_invite_page.dart';
import '../features/auth_admin/presentation/admin_forgot_password_page.dart';
import '../features/auth_admin/presentation/admin_reset_password_page.dart';
import '../features/auth_admin/presentation/sign_in_page.dart';
import '../features/customer_accounts/presentation/customer_account_list_page.dart';
import '../features/documents_cms/presentation/document_detail_page.dart';
import '../features/documents_cms/presentation/document_list_page.dart';
import '../features/commercial_catalog/presentation/commercial_catalog_page.dart';
import '../features/hoa_management/presentation/hoa_detail_page.dart';
import '../features/hoa_management/presentation/hoa_list_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_announcements_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_documents_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_manager_dashboard_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_resident_list_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_service_schedules_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_staff_page.dart';
import '../features/hoa_manager_experience/presentation/hoa_tickets_page.dart';
import '../features/schedules_admin/presentation/service_schedule_detail_page.dart';
import '../features/schedules_admin/presentation/service_schedule_list_page.dart';
import '../features/resident_portal_auth/presentation/activation_code_verification_page.dart';
import '../features/resident_portal_auth/presentation/customer_document_view_page.dart';
import '../features/resident_portal_auth/presentation/customer_portal_home_page.dart';
import '../features/resident_portal_auth/presentation/customer_service_issue_page.dart';
import '../features/resident_portal_auth/presentation/customer_ticket_detail_page.dart';
import '../features/resident_portal_auth/presentation/email_verification_pending_page.dart';
import '../features/resident_portal_auth/presentation/registration_success_page.dart';
import '../features/resident_portal_auth/presentation/resident_account_setup_page.dart';
import '../features/resident_portal_auth/presentation/resident_email_confirmation_page.dart';
import '../features/resident_portal_auth/presentation/resident_forgot_password_page.dart';
import '../features/resident_portal_auth/presentation/resident_registration_page.dart';
import '../features/resident_portal_auth/presentation/resident_reset_password_page.dart';
import '../features/ticket_operations/domain/ticket.dart';
import '../features/ticket_operations/presentation/ticket_dashboard_page.dart';
import '../features/ticket_operations/presentation/ticket_detail_page.dart';
import '../features/ticket_operations/presentation/ticket_list_page.dart';
import '../features/ticket_operations/presentation/resident_service_issue_page.dart';
import '../features/tenant_management/presentation/tenant_detail_page.dart';
import '../features/tenant_management/presentation/tenant_list_page.dart';
import '../features/user_management/presentation/user_detail_page.dart';
import '../features/user_management/presentation/user_list_page.dart';
import '../features/verification_admin/presentation/resident_verification_detail_page.dart';
import '../features/verification_admin/presentation/resident_verification_list_page.dart';

final currentAdminRoleProvider = currentAdminContextSummaryProvider;

const _residentLastTenantCodeKey = 'resident_last_tenant_code';
const _residentPendingTenantCodeKey = 'resident_pending_tenant_code';

final adminRouterProvider = Provider<GoRouter>((ref) {
  String resolveHomeRoute() {
    final accessState = ref.read(activeAdminAccessProvider);
    final access = accessState.asData?.value;

    if (access == null) {
      return '/admin';
    }

    if (access.isHoaScopedOnly) {
      if (!access.hasAnyRoleCode(const {'hoa_manager', 'hoa_board'})) {
        return '/admin/hoa/documents';
      }
      return '/admin/hoa';
    }

    if (access.isTenantScopedOnly) {
      return '/admin';
    }

    return '/admin';
  }

  return GoRouter(
    initialLocation: '/admin',
    redirect: (context, state) {
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      final path = state.uri.path;
      final fragmentRoute = _normalizedFragmentRoute(Uri.base);
      final residentPortalFlow = state.uri.queryParameters['portal_flow'];
      final residentPortalTenant = state.uri.queryParameters['tenant'];
      final isSignIn = path == '/sign-in';
      final isPasswordFlow =
          path == '/forgot-password' || path == '/reset-password';
      final isAcceptInvite =
          path == '/accept-invite' || path.startsWith('/accept-invite/');
      final isResidentPortal = path == '/portal' || path.startsWith('/portal/');
      final canHonorFragmentRoute =
          path == '/' || isSignIn || isPasswordFlow || isAcceptInvite;

      if (fragmentRoute != null &&
          canHonorFragmentRoute &&
          fragmentRoute.startsWith('/portal/') &&
          !isResidentPortal) {
        return fragmentRoute;
      }

      if (fragmentRoute != null &&
          canHonorFragmentRoute &&
          fragmentRoute.startsWith('/accept-invite') &&
          _routeContainsAuthPayload(fragmentRoute) &&
          !isAcceptInvite) {
        return fragmentRoute;
      }

      if (fragmentRoute != null &&
          canHonorFragmentRoute &&
          fragmentRoute.startsWith('/reset-password') &&
          _routeContainsAuthPayload(fragmentRoute) &&
          path != '/reset-password') {
        return fragmentRoute;
      }

      if (path == '/' &&
          residentPortalFlow == 'resident_confirm' &&
          residentPortalTenant != null &&
          residentPortalTenant.trim().isNotEmpty) {
        return state.uri
            .replace(
              path: '/portal/$residentPortalTenant/confirm-email',
            )
            .toString();
      }

      if (path == '/' && residentPortalFlow == 'resident_confirm') {
        return state.uri
            .replace(
              path: '/portal/confirm-email',
            )
            .toString();
      }

      if (devSecurityBypassEnabled) {
        final devHomeRoute = _devHomeRoute();
        if (path == '/' || isSignIn) return devHomeRoute;
        if (isAcceptInvite &&
            !_routeContainsAuthPayload(state.uri.toString())) {
          return devHomeRoute;
        }
        return null;
      }

      if (_isInstalledAppLaunchRoute(path)) {
        final residentLaunchRoute = _residentLaunchRouteFromStorage(user);
        if (residentLaunchRoute != null) return residentLaunchRoute;
      }

      if (path == '/') {
        return user == null ? '/sign-in' : resolveHomeRoute();
      }

      if (isAcceptInvite) {
        if (path != '/accept-invite') {
          return state.uri.replace(path: '/accept-invite').toString();
        }
        return null;
      }

      if (isResidentPortal) {
        final segments = state.uri.pathSegments;
        if (segments.length == 2 && segments[1] == 'confirm-email') {
          return null;
        }

        if (segments.length == 2) {
          final tenantCode = segments[1];
          _rememberResidentTenantCode(tenantCode);
          return '/portal/$tenantCode/register';
        }

        if (segments.length >= 3) {
          final tenantCode = segments[1];
          final leaf = segments[2];
          _rememberResidentTenantCode(tenantCode);

          const protectedPortalLeaves = {
            'activation-code',
            'documents',
            'home',
            'service-issue',
            'service-issues',
            'setup-account',
          };
          if (user == null && protectedPortalLeaves.contains(leaf)) {
            return '/portal/$tenantCode/sign-in';
          }
        }

        return null;
      }

      if (user == null) {
        return isSignIn || isPasswordFlow ? null : '/sign-in';
      }

      final access = ref.read(adminAccessProvider).asData?.value;
      if (access != null && !_hasAdminPortalAccess(access)) {
        final residentRoute = _residentHomeRouteFromStorage();
        if (residentRoute != null && !isResidentPortal) {
          return residentRoute;
        }
        if (path.startsWith('/admin')) return '/sign-in';
      }

      if (isSignIn && !isPasswordFlow) {
        return resolveHomeRoute();
      }

      if (path == '/admin') {
        final resolvedHome = resolveHomeRoute();
        if (resolvedHome != '/admin') {
          return resolvedHome;
        }
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
        path: '/forgot-password',
        name: 'adminForgotPassword',
        builder: (context, state) => const AdminForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'adminResetPassword',
        builder: (context, state) => const AdminResetPasswordPage(),
      ),
      GoRoute(
        path: '/accept-invite',
        name: 'acceptInvite',
        builder: (context, state) => const AcceptInvitePage(),
      ),
      GoRoute(
        path: '/portal/confirm-email',
        name: 'genericResidentEmailConfirmation',
        builder: (context, state) =>
            const ResidentEmailConfirmationPage.generic(),
      ),
      GoRoute(
        path: '/portal/:tenantCode',
        name: 'residentPortalHome',
        redirect: (context, state) =>
            '/portal/${state.pathParameters['tenantCode']!}/register',
      ),
      GoRoute(
        path: '/portal/:tenantCode/register',
        name: 'residentPortalRegister',
        builder: (context, state) => ResidentRegistrationPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/sign-in',
        name: 'residentPortalSignIn',
        builder: (context, state) => SignInPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/forgot-password',
        name: 'residentPortalForgotPassword',
        builder: (context, state) => ResidentForgotPasswordPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/reset-password',
        name: 'residentPortalResetPassword',
        builder: (context, state) => ResidentResetPasswordPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/setup-account',
        name: 'residentPortalSetupAccount',
        builder: (context, state) => ResidentAccountSetupPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/home',
        name: 'customerPortalHome',
        builder: (context, state) => CustomerPortalHomePage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/documents/:documentId',
        name: 'customerPortalDocument',
        builder: (context, state) => CustomerDocumentViewPage(
          tenantCode: state.pathParameters['tenantCode']!,
          documentId: state.pathParameters['documentId']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/service-issue',
        name: 'customerPortalServiceIssue',
        builder: (context, state) => CustomerServiceIssuePage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/service-issues/:ticketId',
        name: 'customerPortalTicketDetail',
        builder: (context, state) => CustomerTicketDetailPage(
          tenantCode: state.pathParameters['tenantCode']!,
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/email-verification-pending',
        name: 'residentPortalEmailVerificationPending',
        builder: (context, state) => EmailVerificationPendingPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/confirm-email',
        name: 'residentPortalConfirmEmailGeneric',
        builder: (context, state) =>
            const ResidentEmailConfirmationPage.generic(),
      ),
      GoRoute(
        path: '/portal/:tenantCode/confirm-email',
        name: 'residentPortalConfirmEmail',
        builder: (context, state) => ResidentEmailConfirmationPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/activation-code',
        name: 'residentPortalActivationCode',
        builder: (context, state) => ActivationCodeVerificationPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
      ),
      GoRoute(
        path: '/portal/:tenantCode/success',
        name: 'residentPortalSuccess',
        builder: (context, state) => RegistrationSuccessPage(
          tenantCode: state.pathParameters['tenantCode']!,
        ),
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
            builder: (context, state) => const AnalyticsDashboardPage()
                .protectedByFeature(TenantFeature.analyticsDashboard)
                .protectedBy(AdminPermissions.dashboard),
          ),
          GoRoute(
            path: '/admin/hoa',
            name: 'hoaManagerDashboard',
            builder: (context, state) => const HoaManagerDashboardPage()
                .protectedBy(AdminPermissions.hoaScoped),
          ),
          GoRoute(
            path: '/admin/hoa/residents',
            name: 'hoaResidentList',
            builder: (context, state) => const HoaResidentListPage()
                .protectedBy(AdminPermissions.hoaScoped),
          ),
          GoRoute(
            path: '/admin/hoa/staff',
            name: 'hoaStaff',
            builder: (context, state) =>
                const HoaStaffPage().protectedBy(AdminPermissions.hoaScoped),
          ),
          GoRoute(
            path: '/admin/hoa/documents',
            name: 'hoaDocuments',
            builder: (context, state) => const HoaDocumentsPage()
                .protectedBy(AdminPermissions.hoaDocuments),
          ),
          GoRoute(
            path: '/admin/hoa/announcements',
            name: 'hoaAnnouncements',
            builder: (context, state) => const HoaAnnouncementsPage()
                .protectedBy(AdminPermissions.hoaAnnouncements),
          ),
          GoRoute(
            path: '/admin/hoa/tickets',
            name: 'hoaTickets',
            builder: (context, state) =>
                const HoaTicketsPage().protectedBy(AdminPermissions.hoaTickets),
          ),
          GoRoute(
            path: '/admin/hoa/tickets/new',
            name: 'residentServiceIssueNew',
            builder: (context, state) => const ResidentServiceIssuePage()
                .protectedBy(AdminPermissions.hoaTickets),
          ),
          GoRoute(
            path: '/admin/hoa/service-schedules',
            name: 'hoaServiceSchedules',
            builder: (context, state) => const HoaServiceSchedulesPage()
                .protectedBy(AdminPermissions.hoaSchedules),
          ),
          GoRoute(
            path: '/admin/commercial-catalog',
            name: 'commercialCatalog',
            builder: (context, state) => const CommercialCatalogPage()
                .protectedBy(AdminPermissions.commercialCatalog),
          ),
          GoRoute(
            path: '/admin/tenants',
            name: 'tenantList',
            builder: (context, state) =>
                const TenantListPage().protectedBy(AdminPermissions.tenantRead),
          ),
          GoRoute(
            path: '/admin/tenants/:tenantId',
            name: 'tenantDetail',
            builder: (context, state) => TenantDetailPage(
              tenantId: state.pathParameters['tenantId']!,
            ).protectedBy(AdminPermissions.tenantRead),
          ),
          GoRoute(
            path: '/admin/hoas',
            name: 'hoaList',
            builder: (context, state) =>
                const HoaListPage().protectedBy(AdminPermissions.hoaRead),
          ),
          GoRoute(
            path: '/admin/customer-accounts',
            name: 'customerAccountList',
            builder: (context, state) => const CustomerAccountListPage()
                .protectedBy(AdminPermissions.customerAccountsRead),
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
            builder: (context, state) => const AddressListPage()
                .protectedBy(AdminPermissions.addressRead),
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
            builder: (context, state) => const ActivationCodeListPage()
                .protectedBy(AdminPermissions.activationCodes),
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
            builder: (context, state) => const ResidentVerificationListPage()
                .protectedBy(AdminPermissions.verificationRead),
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
            builder: (context, state) => const AnnouncementListPage()
                .protectedBy(AdminPermissions.announcementsRead),
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
            builder: (context, state) => const DocumentListPage()
                .protectedBy(AdminPermissions.documentsRead),
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
            builder: (context, state) => const ServiceScheduleListPage()
                .protectedBy(AdminPermissions.schedulesRead),
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
            builder: (context, state) => const TicketListPage()
                .protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/csr',
            name: 'ticketCsrDashboard',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.csr,
            )
                .protectedByFeature(TenantFeature.advancedTicketManagement)
                .protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/dispatch',
            name: 'ticketDispatchDashboard',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.dispatch,
            )
                .protectedByFeature(TenantFeature.dispatchDashboard)
                .protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/urgent',
            name: 'ticketUrgentQueue',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.urgent,
            )
                .protectedByFeature(TenantFeature.advancedTicketManagement)
                .protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/aging',
            name: 'ticketAgingQueue',
            builder: (context, state) => const TicketDashboardPage(
              queue: TicketQueue.aging,
            )
                .protectedByFeature(TenantFeature.advancedTicketManagement)
                .protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/tickets/:ticketId',
            name: 'ticketDetail',
            builder: (context, state) => TicketDetailPage(
              ticketId: state.pathParameters['ticketId']!,
              backSource: state.uri.queryParameters['from'],
            ).protectedBy(AdminPermissions.ticketsRead),
          ),
          GoRoute(
            path: '/admin/users',
            name: 'userList',
            builder: (context, state) => const UserListPage()
                .protectedBy(AdminPermissions.userManagement),
          ),
          GoRoute(
            path: '/admin/users/:userId',
            name: 'userDetail',
            builder: (context, state) => UserDetailPage(
              userId: state.pathParameters['userId']!,
            ).protectedBy(AdminPermissions.userManagement),
          ),
          GoRoute(
            path: '/admin/unauthorized',
            name: 'unauthorized',
            builder: (context, state) => const UnauthorizedPage(),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            name: 'auditLogs',
            builder: (context, state) => const AuditLogListPage()
                .protectedBy(AdminPermissions.auditRead),
          ),
        ],
      ),
    ],
  );
});

String? _normalizedFragmentRoute(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.isEmpty) return null;

  final normalized = fragment.startsWith('/')
      ? fragment
      : fragment.startsWith('#/')
          ? fragment.substring(1)
          : fragment.startsWith('#')
              ? fragment.substring(1)
              : '/$fragment';

  if (!normalized.startsWith('/')) return null;
  return normalized;
}

bool _routeContainsAuthPayload(String route) {
  final queryStart = route.indexOf('?');
  if (queryStart < 0) return false;
  final query = route.substring(queryStart + 1);
  return query.contains('access_token=') ||
      query.contains('refresh_token=') ||
      query.contains('token_hash=') ||
      query.contains('code=') ||
      query.contains('type=invite') ||
      query.contains('type=recovery') ||
      query.contains('error_description=');
}

bool _hasAdminPortalAccess(AdminAccess access) {
  if (access.hasGlobalRoleAssignment || access.hasTenantRoleAssignment) {
    return true;
  }

  return access.hoaRoles.any(
    (role) => role.code == 'hoa_manager' || role.code == 'hoa_board',
  );
}

String? _residentHomeRouteFromStorage() {
  final tenantCode = html.window.localStorage[_residentLastTenantCodeKey] ??
      html.window.localStorage[_residentPendingTenantCodeKey];
  final normalized = tenantCode?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return '/portal/$normalized/home';
}

String? _residentLaunchRouteFromStorage(User? user) {
  final tenantCode = html.window.localStorage[_residentLastTenantCodeKey] ??
      html.window.localStorage[_residentPendingTenantCodeKey];
  final normalized = tenantCode?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return user == null
      ? '/portal/$normalized/sign-in'
      : '/portal/$normalized/home';
}

bool _isInstalledAppLaunchRoute(String path) {
  if (path != '/' && path != '/sign-in') return false;

  final standaloneDisplay = html.window
      .matchMedia(
        '(display-mode: standalone)',
      )
      .matches;
  final fullscreenDisplay = html.window
      .matchMedia(
        '(display-mode: fullscreen)',
      )
      .matches;
  final minimalUiDisplay = html.window
      .matchMedia(
        '(display-mode: minimal-ui)',
      )
      .matches;

  return standaloneDisplay || fullscreenDisplay || minimalUiDisplay;
}

void _rememberResidentTenantCode(String tenantCode) {
  final normalized = tenantCode.trim();
  if (normalized.isEmpty || normalized == 'confirm-email') return;
  html.window.localStorage[_residentLastTenantCodeKey] = normalized;
}

String _devHomeRoute() {
  final storedContext = html.window.localStorage['selected_admin_context_id'];
  if (storedContext?.startsWith('hoa:') ?? false) {
    return '/admin/hoa/documents';
  }
  return '/admin';
}

Future<void> forceAdminSignOut(WidgetRef ref) async {
  if (devSecurityBypassEnabled) {
    setSelectedAdminContextId(ref, null);
    html.window.localStorage.remove('resident_email_callback_payload');
    html.window.localStorage.remove(_residentPendingTenantCodeKey);
    html.window.localStorage.remove('resident_pending_email');
    ref.invalidate(adminAccessProvider);
    ref.invalidate(availableAdminContextsProvider);
    ref.invalidate(activeAdminContextProvider);
    ref.invalidate(activeAdminAccessProvider);
    html.window.history.replaceState(
      null,
      'Customer Portal',
      '${html.window.location.origin}/admin',
    );
    return;
  }

  setSelectedAdminContextId(ref, null);
  html.window.localStorage.remove('resident_email_callback_payload');
  html.window.localStorage.remove(_residentPendingTenantCodeKey);
  html.window.localStorage.remove('resident_pending_email');
  await ref.read(supabaseClientProvider).auth.signOut();
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(adminAccessProvider);
  ref.invalidate(availableAdminContextsProvider);
  ref.invalidate(activeAdminContextProvider);
  ref.invalidate(activeAdminAccessProvider);
  html.window.history.replaceState(
    null,
    'Customer Portal',
    '${html.window.location.origin}/sign-in',
  );
}

class _PortalChromeText {
  const _PortalChromeText({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  String get fullTitle => '$title $subtitle';
}

_PortalChromeText _portalChromeText(AdminContext? context) {
  if (context == null || context.isPlatform) {
    return const _PortalChromeText(
      title: 'Customer Portal',
      subtitle: 'Platform Portal',
    );
  }

  final scopeName = context.scopeName?.trim();
  if (context.isTenant) {
    return _PortalChromeText(
      title: scopeName == null || scopeName.isEmpty
          ? 'Customer Portal'
          : scopeName,
      subtitle: 'Management Portal',
    );
  }

  if (context.isHoa) {
    return _PortalChromeText(
      title: scopeName == null || scopeName.isEmpty
          ? 'Customer Portal'
          : scopeName,
      subtitle: 'Community Portal',
    );
  }

  return const _PortalChromeText(
    title: 'Customer Portal',
    subtitle: 'Management Portal',
  );
}

class AdminNavigationShell extends ConsumerStatefulWidget {
  const AdminNavigationShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<AdminNavigationShell> createState() =>
      _AdminNavigationShellState();
}

class _AdminNavigationShellState extends ConsumerState<AdminNavigationShell> {
  bool _isCollapsed = false;
  bool _isSigningOut = false;
  bool _isRedirectingNonAdmin = false;

  @override
  Widget build(BuildContext context) {
    if (_isSigningOut) {
      return const Scaffold(body: SizedBox.expand());
    }

    final accessState = ref.watch(adminAccessProvider);
    final access = accessState.asData?.value;
    if (access != null && !_hasAdminPortalAccess(access)) {
      _redirectNonAdminSession();
      return const Scaffold(body: SizedBox.expand());
    }

    final passwordSetupRequired =
        ref.watch(currentAdminProfileProvider).maybeWhen(
              data: (profile) => profile?.requiresPasswordSetup ?? false,
              orElse: () => false,
            );

    if (passwordSetupRequired) return const _AdminPasswordSetupGate();

    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final chromeText = ref.watch(activeAdminContextProvider).maybeWhen(
          data: _portalChromeText,
          orElse: () => _portalChromeText(null),
        );
    final nav = _AdminSidebar(
      currentPath: widget.currentPath,
      isCollapsed: isCompact ? false : _isCollapsed,
      onToggleCollapsed:
          isCompact ? null : () => setState(() => _isCollapsed = !_isCollapsed),
      onSignOut: _signOut,
    );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(chromeText.fullTitle),
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
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    await forceAdminSignOut(ref);
    if (mounted) context.go('/sign-in');
  }

  void _redirectNonAdminSession() {
    if (_isRedirectingNonAdmin) return;
    _isRedirectingNonAdmin = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final residentRoute = _residentHomeRouteFromStorage();
      if (residentRoute != null) {
        context.go(residentRoute);
        return;
      }

      await forceAdminSignOut(ref);
      if (mounted) context.go('/sign-in');
    });
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.title,
    required this.subtitle,
    required this.fullTitle,
  });

  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final String title;
  final String subtitle;
  final String fullTitle;

  @override
  Widget build(BuildContext context) {
    final toggle = onToggleCollapsed == null
        ? null
        : IconButton(
            tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            onPressed: onToggleCollapsed,
            icon: Icon(
              isCollapsed
                  ? Icons.keyboard_double_arrow_right
                  : Icons.keyboard_double_arrow_left,
            ),
          );

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: fullTitle,
              child: const CircleAvatar(
                radius: 20,
                child: Icon(Icons.delete_outline),
              ),
            ),
            if (toggle != null) ...[
              const SizedBox(height: 6),
              toggle,
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            child: Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (toggle != null) toggle,
        ],
      ),
    );
  }
}

class _AdminContextSelector extends ConsumerWidget {
  const _AdminContextSelector({
    required this.currentPath,
  });

  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contexts = ref.watch(availableAdminContextsProvider);
    final activeContext = ref.watch(activeAdminContextProvider);

    return contexts.when(
      data: (items) {
        if (items.length <= 1) return const SizedBox.shrink();

        final activeId = activeContext.asData?.value?.id ?? items.first.id;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: DropdownButtonFormField<String>(
            initialValue: items.any((item) => item.id == activeId)
                ? activeId
                : items.first.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Current view',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.switch_account_outlined),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setSelectedAdminContextId(ref, value);
              ref.invalidate(activeAdminContextProvider);
              ref.invalidate(activeAdminAccessProvider);
              _redirectForContext(
                  context, items.firstWhere((item) => item.id == value));
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text('Unable to load views: $error'),
      ),
    );
  }

  void _redirectForContext(BuildContext context, AdminContext adminContext) {
    if (adminContext.isHoa && !adminContext.isHoaManagement) {
      if (!currentPath.startsWith('/admin/hoa/documents') &&
          !currentPath.startsWith('/admin/hoa/announcements') &&
          !currentPath.startsWith('/admin/hoa/service-schedules') &&
          !currentPath.startsWith('/admin/hoa/tickets')) {
        context.go('/admin/hoa/documents');
      }
      return;
    }
    if (adminContext.isHoa && currentPath.startsWith('/admin/hoa')) {
      return;
    }
    if (adminContext.isHoa) {
      context.go('/admin/hoa');
      return;
    }

    if (!adminContext.isHoa && currentPath.startsWith('/admin/hoa')) {
      context.go('/admin');
    }
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.currentPath,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onSignOut,
  });

  final String currentPath;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final Future<void> Function() onSignOut;

  static const _items = [
    _AdminNavItem(
      label: 'Dashboard',
      permissionRule: AdminPermissions.dashboard,
      path: '/admin',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin'],
      exact: true,
      feature: TenantFeature.analyticsDashboard,
    ),
    _AdminNavItem(
      label: 'Plans & Add-Ons',
      permissionRule: AdminPermissions.commercialCatalog,
      path: '/admin/commercial-catalog',
      icon: Icons.payments_outlined,
      activePrefixes: ['/admin/commercial-catalog'],
    ),
    _AdminNavItem(
      label: 'Platform Tenants',
      permissionRule: AdminPermissions.tenantRead,
      path: '/admin/tenants',
      icon: Icons.business_center_outlined,
      activePrefixes: ['/admin/tenants'],
    ),
    _AdminNavItem(
      label: 'Customer Accounts',
      permissionRule: AdminPermissions.customerAccountsRead,
      path: '/admin/customer-accounts',
      icon: Icons.account_tree_outlined,
      activePrefixes: ['/admin/customer-accounts'],
    ),
    _AdminNavItem(
      label: 'Community Management',
      permissionRule: AdminPermissions.hoaRead,
      path: '/admin/hoas',
      icon: Icons.domain_outlined,
      activePrefixes: ['/admin/hoas'],
    ),
    _AdminNavItem(
      label: 'Service Locations',
      permissionRule: AdminPermissions.addressRead,
      path: '/admin/addresses',
      icon: Icons.location_on_outlined,
      activePrefixes: ['/admin/addresses'],
    ),
    _AdminNavItem(
      label: 'Customer Verification',
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
      permissionRule: AdminPermissions.userManagement,
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

  static const _tenantItems = [
    _AdminNavItem(
      label: 'Dashboard',
      permissionRule: AdminPermissions.dashboard,
      path: '/admin',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin'],
      exact: true,
      feature: TenantFeature.analyticsDashboard,
    ),
    _AdminNavItem(
      label: 'Customer Accounts',
      permissionRule: AdminPermissions.customerAccountsRead,
      path: '/admin/customer-accounts',
      icon: Icons.account_tree_outlined,
      activePrefixes: ['/admin/customer-accounts'],
    ),
    _AdminNavItem(
      label: 'Community Management',
      permissionRule: AdminPermissions.hoaRead,
      path: '/admin/hoas',
      icon: Icons.domain_outlined,
      activePrefixes: ['/admin/hoas'],
    ),
    _AdminNavItem(
      label: 'Service Locations',
      permissionRule: AdminPermissions.addressRead,
      path: '/admin/addresses',
      icon: Icons.location_on_outlined,
      activePrefixes: ['/admin/addresses'],
    ),
    _AdminNavItem(
      label: 'Customer Verification',
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
      permissionRule: AdminPermissions.userManagement,
      path: '/admin/users',
      icon: Icons.manage_accounts_outlined,
      activePrefixes: ['/admin/users'],
    ),
  ];

  static const _hoaItems = [
    _AdminNavItem(
      label: 'Community Dashboard',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa',
      icon: Icons.dashboard_outlined,
      activePrefixes: ['/admin/hoa'],
      exact: true,
    ),
    _AdminNavItem(
      label: 'Customers',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa/residents',
      icon: Icons.people_outline,
      activePrefixes: ['/admin/hoa/residents'],
    ),
    _AdminNavItem(
      label: 'Community Staff',
      permissionRule: AdminPermissions.hoaScoped,
      path: '/admin/hoa/staff',
      icon: Icons.manage_accounts_outlined,
      activePrefixes: ['/admin/hoa/staff'],
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

  static const _residentItems = [
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
      label: 'Service Schedules',
      permissionRule: AdminPermissions.hoaSchedules,
      path: '/admin/hoa/service-schedules',
      icon: Icons.event_repeat_outlined,
      activePrefixes: ['/admin/hoa/service-schedules'],
    ),
    _AdminNavItem(
      label: 'Tickets',
      permissionRule: AdminPermissions.hoaTickets,
      path: '/admin/hoa/tickets',
      icon: Icons.confirmation_number_outlined,
      activePrefixes: ['/admin/hoa/tickets'],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentAdminRoleProvider);
    final profile = ref.watch(currentAdminProfileProvider);
    final activeContext = ref.watch(activeAdminContextProvider);
    final access = ref.watch(activeAdminAccessProvider);
    final chromeText = activeContext.maybeWhen(
      data: _portalChromeText,
      orElse: () => _portalChromeText(null),
    );
    final visibleItems = access.maybeWhen(
      data: (value) {
        final context = activeContext.asData?.value;
        final source = context?.isHoa == true
            ? context?.isHoaManagement == true
                ? _hoaItems
                : _residentItems
            : context?.isTenant == true
                ? _tenantItems
                : _items;
        return source.where((item) => item.canShow(value, ref)).toList();
      },
      orElse: () => [_items.first],
    );
    final width = isCollapsed ? 84.0 : 292.0;

    return AnimatedContainer(
      // Width animation briefly creates invalid intermediate layouts for the
      // collapsed rail, so switch instantly and keep the UI overflow-free.
      duration: Duration.zero,
      curve: Curves.easeOutCubic,
      width: width,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SidebarHeader(
              isCollapsed: isCollapsed,
              onToggleCollapsed: onToggleCollapsed,
              title: chromeText.title,
              subtitle: chromeText.subtitle,
              fullTitle: chromeText.fullTitle,
            ),
            if (!isCollapsed) ...[
              _AdminContextSelector(
                currentPath: currentPath,
              ),
              const Divider(height: 1),
            ],
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
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
                displayName: profile.when(
                  data: (value) =>
                      value?.displayName ??
                      user?.email ??
                      user?.id ??
                      'Unknown user',
                  loading: () => user?.email ?? user?.id ?? 'Loading user...',
                  error: (_, __) => user?.email ?? user?.id ?? 'Unknown user',
                ),
                email: profile.when(
                  data: (value) =>
                      value?.email ?? user?.email ?? user?.id ?? 'Unknown user',
                  loading: () => user?.email ?? user?.id ?? 'Loading user...',
                  error: (_, __) => user?.email ?? user?.id ?? 'Unknown user',
                ),
                role: role.when(
                  data: (value) => value,
                  loading: () => 'Loading role...',
                  error: (_, __) => 'Role unavailable',
                ),
                isCollapsed: isCollapsed,
                onSignOut: onSignOut,
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
    required this.displayName,
    required this.email,
    required this.role,
    required this.isCollapsed,
    required this.onSignOut,
  });

  final String displayName;
  final String email;
  final String role;
  final bool isCollapsed;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final tooltipMessage =
        displayName == email ? '$email\n$role' : '$displayName\n$email\n$role';

    if (isCollapsed) {
      return Column(
        children: [
          Tooltip(
            message: tooltipMessage,
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
                  child: Tooltip(
                    message: tooltipMessage,
                    waitDuration: const Duration(milliseconds: 350),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (displayName != email)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
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
    this.feature,
  });

  final String label;
  final AdminPermissionRule permissionRule;
  final String path;
  final IconData icon;
  final List<String> activePrefixes;
  final bool exact;
  final TenantFeature? feature;

  bool canShow(AdminAccess access, WidgetRef ref) {
    if (devSecurityBypassEnabled) return true;
    if (permissionRule.isOpen) return true;
    final hasPermissions = permissionRule.permissions.isNotEmpty &&
        access.canAny(permissionRule.permissions);
    final hasRoles = permissionRule.roleCodes.isNotEmpty &&
        access.hasAnyRoleCode(permissionRule.roleCodes);
    if (!hasPermissions && !hasRoles) return false;

    final feature = this.feature;
    if (feature == null || access.isPlatformOperator) return true;
    if (access.tenantScopeIds.isEmpty) return true;

    return ref.watch(adminFeatureEntitlementProvider(feature)).maybeWhen(
          data: (result) => result.isEnabled,
          orElse: () => false,
        );
  }

  bool isActive(String currentPath) {
    if (exact) {
      return currentPath == path;
    }

    return activePrefixes.any((prefix) => currentPath.startsWith(prefix));
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

class _AdminPasswordSetupGate extends ConsumerStatefulWidget {
  const _AdminPasswordSetupGate();

  @override
  ConsumerState<_AdminPasswordSetupGate> createState() =>
      _AdminPasswordSetupGateState();
}

class _AdminPasswordSetupGateState
    extends ConsumerState<_AdminPasswordSetupGate> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_reset_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create your password',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finish setting up your portal account to continue.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      validator: _password,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                      validator: _confirmPassword,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _isSaving ? null : _savePassword,
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              await ref
                                  .read(supabaseClientProvider)
                                  .auth
                                  .signOut();
                              if (context.mounted) context.go('/sign-in');
                            },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      final user = client.auth.currentUser;
      if (user != null) {
        final now = DateTime.now().toUtc().toIso8601String();
        await client.from('profiles').update({
          'password_set_at': now,
          'status': 'active',
          'updated_at': now,
        }).eq('id', user.id);
      }

      ref
        ..invalidate(currentAdminProfileProvider)
        ..invalidate(activeAdminAccessProvider);

      if (mounted) context.go('/admin');
    } catch (error) {
      if (mounted) {
        setState(() => _message = _friendlyPasswordError(error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _password(String? value) {
    if (value == null || value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _confirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  String _friendlyPasswordError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'We could not save your password. Please try again.';
    }
    return message;
  }
}
