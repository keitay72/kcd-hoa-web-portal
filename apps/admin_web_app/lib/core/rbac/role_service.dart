import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_access.dart';

abstract interface class RoleService {
  Future<List<AdminRoleAssignment>> globalRolesForUser(String userId);
  Future<List<AdminRoleAssignment>> tenantRolesForUser(String userId);
  Future<List<AdminRoleAssignment>> hoaRolesForUser(String userId);

  // Compatibility bridge while user-management screens still use the old
  // platform-role label for tenant-scoped staff roles.
  Future<List<AdminRoleAssignment>> platformRolesForUser(String userId);
}

class SupabaseRoleService implements RoleService {
  const SupabaseRoleService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminRoleAssignment>> platformRolesForUser(String userId) {
    return tenantRolesForUser(userId);
  }

  @override
  Future<List<AdminRoleAssignment>> globalRolesForUser(String userId) async {
    final rows = await _client
        .from('user_global_roles')
        .select('roles(code, name)')
        .eq('user_id', userId);

    return rows.map((row) {
      final role = row['roles'] as Map<String, dynamic>?;
      final code = role?['code'] as String? ?? 'unknown';
      return AdminRoleAssignment(
        code: code,
        name: role?['name'] as String? ?? code,
      );
    }).toList();
  }

  @override
  Future<List<AdminRoleAssignment>> tenantRolesForUser(String userId) async {
    final rows = await _client
        .from('user_tenant_roles')
        .select('tenant_id, role_id')
        .eq('user_id', userId);

    final roleNames = await _roleNamesById(
      rows.map((row) => row['role_id'] as int),
    );
    final tenantNames = await _tenantNamesById(
      rows.map((row) => row['tenant_id'] as String),
    );

    return rows.map((row) {
      final roleId = row['role_id'] as int;
      final tenantId = row['tenant_id'] as String?;
      final role = roleNames[roleId];
      final code = role?.code ?? 'unknown';
      return AdminRoleAssignment(
        code: code,
        name: role?.name ?? code,
        tenantId: tenantId,
        tenantName: tenantId == null ? null : tenantNames[tenantId],
      );
    }).toList();
  }

  Future<Map<int, _RoleLabel>> _roleNamesById(Iterable<int> roleIds) async {
    final ids = roleIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('roles')
        .select('id, code, name')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as int: _RoleLabel(
          code: row['code'] as String? ?? 'unknown',
          name: row['name'] as String? ?? row['code'] as String? ?? 'Unknown role',
        ),
    };
  }

  Future<Map<String, String>> _tenantNamesById(Iterable<String> tenantIds) async {
    final ids = tenantIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('platform_tenants')
        .select('id, name')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: row['name'] as String? ?? 'Tenant',
    };
  }

  @override
  Future<List<AdminRoleAssignment>> hoaRolesForUser(String userId) async {
    final rows = await _client
        .from('user_hoa_memberships')
        .select('hoa_id, roles(code, name), hoa_communities(name)')
        .eq('user_id', userId)
        .eq('status', 'active');

    return rows.map((row) {
      final role = row['roles'] as Map<String, dynamic>?;
      final hoa = row['hoa_communities'] as Map<String, dynamic>?;
      final code = role?['code'] as String? ?? 'unknown';
      return AdminRoleAssignment(
        code: code,
        name: role?['name'] as String? ?? code,
        hoaId: row['hoa_id'] as String?,
        hoaName: hoa?['name'] as String?,
      );
    }).toList();
  }
}

class _RoleLabel {
  const _RoleLabel({required this.code, required this.name});

  final String code;
  final String name;
}
