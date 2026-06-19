import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dev/dev_security_bypass.dart';
import '../supabase/supabase_provider.dart';
import 'admin_access.dart';
import 'permission_service.dart';
import 'rbac_service.dart';
import 'role_service.dart';

final roleServiceProvider = Provider<RoleService>((ref) {
  return SupabaseRoleService(ref.watch(supabaseClientProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return SupabasePermissionService(ref.watch(supabaseClientProvider));
});

final rbacServiceProvider = Provider<RbacService>((ref) {
  return DefaultRbacService(
    roleService: ref.watch(roleServiceProvider),
    permissionService: ref.watch(permissionServiceProvider),
  );
});

final adminAccessProvider =
    FutureProvider.autoDispose<AdminAccess>((ref) async {
  if (devSecurityBypassEnabled) {
    return _devAdminAccess(ref.watch(supabaseClientProvider));
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const AdminAccess(
      userId: '',
      globalRoles: [],
      tenantRoles: [],
      hoaRoles: [],
      permissions: {},
    );
  }

  return ref.watch(rbacServiceProvider).accessForUser(user.id);
});

final currentAdminRoleSummaryProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final access = await ref.watch(adminAccessProvider.future);
  return access.roleSummary;
});

Future<AdminAccess> _devAdminAccess(SupabaseClient client) async {
  final tenant = await _loadFirstTenant(client);
  final hoa = await _loadFirstHoa(client);

  return AdminAccess(
    userId: devUserId,
    globalRoles: const [
      AdminRoleAssignment(
        code: 'platform_owner',
        name: 'Platform Owner',
      ),
    ],
    tenantRoles: [
      AdminRoleAssignment(
        code: 'tenant_admin',
        name: 'Tenant Admin',
        tenantId: tenant.id,
        tenantName: tenant.name,
      ),
    ],
    hoaRoles: [
      AdminRoleAssignment(
        code: 'hoa_resident',
        name: 'Resident',
        hoaId: hoa.id,
        hoaName: hoa.name,
      ),
    ],
    permissions: devPermissionCodes,
  );
}

Future<({String id, String name})> _loadFirstTenant(
    SupabaseClient client) async {
  try {
    final row = await client
        .from('tenants')
        .select('id, name')
        .order('name')
        .limit(1)
        .maybeSingle();
    return (
      id: row?['id'] as String? ?? devTenantId,
      name: row?['name'] as String? ?? devTenantName,
    );
  } catch (_) {
    return (id: devTenantId, name: devTenantName);
  }
}

Future<({String id, String name})> _loadFirstHoa(SupabaseClient client) async {
  try {
    final row = await client
        .from('hoa_communities')
        .select('id, name')
        .order('name')
        .limit(1)
        .maybeSingle();
    return (
      id: row?['id'] as String? ?? devHoaId,
      name: row?['name'] as String? ?? devHoaName,
    );
  } catch (_) {
    return (id: devHoaId, name: devHoaName);
  }
}
