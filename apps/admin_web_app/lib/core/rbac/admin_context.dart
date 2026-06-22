// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dev/dev_security_bypass.dart';
import '../supabase/supabase_provider.dart';
import 'admin_access.dart';
import 'rbac_providers.dart';

enum AdminContextKind {
  platform,
  tenant,
  hoa,
}

class AdminContext {
  const AdminContext({
    required this.id,
    required this.kind,
    required this.label,
    required this.roles,
    this.scopeId,
    this.scopeName,
  });

  final String id;
  final AdminContextKind kind;
  final String label;
  final List<AdminRoleAssignment> roles;
  final String? scopeId;
  final String? scopeName;

  bool get isPlatform => kind == AdminContextKind.platform;
  bool get isTenant => kind == AdminContextKind.tenant;
  bool get isHoa => kind == AdminContextKind.hoa;
  bool get isHoaManagement => roles.any(
        (role) => role.code == 'hoa_manager' || role.code == 'hoa_board',
      );
  bool get isResident => roles.any((role) => role.code == 'hoa_resident');

  Set<String> get roleCodes {
    return roles
        .map((role) => role.code)
        .where((code) => code != 'unknown')
        .toSet();
  }

  String get roleSummary {
    if (roles.isEmpty) return 'No role assigned';
    final labels = roles.map((role) => role.name).toSet().toList()..sort();
    return labels.join(', ');
  }
}

final selectedAdminContextIdProvider = StateProvider<String?>((ref) {
  return html.window.localStorage['selected_admin_context_id'];
});

void setSelectedAdminContextId(WidgetRef ref, String? contextId) {
  ref.read(selectedAdminContextIdProvider.notifier).state = contextId;
  if (contextId == null || contextId.isEmpty) {
    html.window.localStorage.remove('selected_admin_context_id');
  } else {
    html.window.localStorage['selected_admin_context_id'] = contextId;
  }
}

final availableAdminContextsProvider =
    FutureProvider.autoDispose<List<AdminContext>>((ref) async {
  final access = await ref.watch(adminAccessProvider.future);
  return _contextsForAccess(access);
});

final activeAdminContextProvider =
    FutureProvider.autoDispose<AdminContext?>((ref) async {
  final selectedId = ref.watch(selectedAdminContextIdProvider);
  final contexts = await ref.watch(availableAdminContextsProvider.future);
  if (contexts.isEmpty) return null;

  if (selectedId != null) {
    for (final context in contexts) {
      if (context.id == selectedId) {
        html.window.localStorage['selected_admin_context_id'] = context.id;
        return context;
      }
    }
  }

  final fallback = contexts.first;
  html.window.localStorage['selected_admin_context_id'] = fallback.id;
  return fallback;
});

final activeAdminAccessProvider =
    FutureProvider.autoDispose<AdminAccess>((ref) async {
  final access = await ref.watch(adminAccessProvider.future);
  final context = await ref.watch(activeAdminContextProvider.future);
  if (context == null) {
    return access.scopedTo(roles: const [], permissions: const {});
  }

  if (devSecurityBypassEnabled) {
    return access.scopedTo(
      roles: context.roles,
      permissions: devPermissionCodes,
    );
  }

  final permissions = await ref
      .watch(permissionServiceProvider)
      .permissionCodesForRoles(context.roleCodes);

  return access.scopedTo(
    roles: context.roles,
    permissions: permissions,
  );
});

final currentAdminContextSummaryProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final context = await ref.watch(activeAdminContextProvider.future);
  if (context == null) return 'No role assigned';
  return context.label;
});

final activeHoaIdsProvider =
    FutureProvider.autoDispose<Set<String>?>((ref) async {
  final context = await ref.watch(activeAdminContextProvider.future);
  if (context == null || context.isPlatform) return null;

  if (context.isHoa) {
    final hoaId = context.scopeId;
    return hoaId == null ? const <String>{} : {hoaId};
  }

  final tenantId = context.scopeId;
  if (tenantId == null) return const <String>{};

  final rows = await ref
      .watch(supabaseClientProvider)
      .from('hoa_communities')
      .select('id')
      .eq('tenant_id', tenantId);

  return rows.map((row) => row['id'] as String).toSet();
});

List<AdminContext> _contextsForAccess(AdminAccess access) {
  final contexts = <AdminContext>[];

  if (access.globalRoles.isNotEmpty) {
    contexts.add(
      AdminContext(
        id: 'platform',
        kind: AdminContextKind.platform,
        label: 'Platform Admin',
        roles: access.globalRoles,
      ),
    );
  }

  final tenantRolesById = <String, List<AdminRoleAssignment>>{};
  for (final role in access.tenantRoles) {
    final tenantId = role.tenantId;
    if (tenantId == null) continue;
    tenantRolesById
        .putIfAbsent(tenantId, () => <AdminRoleAssignment>[])
        .add(role);
  }
  final tenantIds = tenantRolesById.keys.toList()
    ..sort((a, b) {
      final left = tenantRolesById[a]!.first.tenantName ?? a;
      final right = tenantRolesById[b]!.first.tenantName ?? b;
      return left.compareTo(right);
    });
  for (final tenantId in tenantIds) {
    final roles = tenantRolesById[tenantId]!;
    final tenantName = roles.first.tenantName ?? tenantId;
    contexts.add(
      AdminContext(
        id: 'tenant:$tenantId',
        kind: AdminContextKind.tenant,
        label: '${_tenantContextPrefix(roles)} of $tenantName',
        roles: roles,
        scopeId: tenantId,
        scopeName: tenantName,
      ),
    );
  }

  final hoaRolesById = <String, List<AdminRoleAssignment>>{};
  for (final role in access.hoaRoles) {
    final hoaId = role.hoaId;
    if (hoaId == null) continue;
    hoaRolesById.putIfAbsent(hoaId, () => <AdminRoleAssignment>[]).add(role);
  }
  final hoaIds = hoaRolesById.keys.toList()
    ..sort((a, b) {
      final left = hoaRolesById[a]!.first.hoaName ?? a;
      final right = hoaRolesById[b]!.first.hoaName ?? b;
      return left.compareTo(right);
    });
  for (final hoaId in hoaIds) {
    final roles = hoaRolesById[hoaId]!;
    final hoaName = roles.first.hoaName ?? hoaId;
    contexts.add(
      AdminContext(
        id: 'hoa:$hoaId',
        kind: AdminContextKind.hoa,
        label: '${_hoaContextPrefix(roles)} of $hoaName',
        roles: roles,
        scopeId: hoaId,
        scopeName: hoaName,
      ),
    );
  }

  return contexts;
}

String _tenantContextPrefix(List<AdminRoleAssignment> roles) {
  if (roles.any((role) => role.code == 'tenant_owner')) return 'Tenant Owner';
  if (roles.any((role) => role.code == 'tenant_admin')) return 'Tenant Admin';
  if (roles.any((role) => role.code == 'tenant_manager')) {
    return 'Tenant Manager';
  }
  if (roles.any((role) => role.code == 'tenant_csr')) {
    return 'Customer Service';
  }
  if (roles.any((role) => role.code == 'tenant_dispatch')) return 'Dispatch';
  return 'Tenant Staff';
}

String _hoaContextPrefix(List<AdminRoleAssignment> roles) {
  if (roles.any((role) => role.code == 'hoa_manager')) return 'Manager';
  if (roles.any((role) => role.code == 'hoa_board')) return 'Board Member';
  if (roles.any((role) => role.code == 'hoa_resident')) return 'Resident';
  return 'HOA Member';
}
