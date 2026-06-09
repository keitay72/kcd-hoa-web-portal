import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_access.dart';

abstract interface class RoleService {
  Future<List<AdminRoleAssignment>> platformRolesForUser(String userId);
  Future<List<AdminRoleAssignment>> hoaRolesForUser(String userId);
}

class SupabaseRoleService implements RoleService {
  const SupabaseRoleService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminRoleAssignment>> platformRolesForUser(String userId) async {
    final rows = await _client
        .from('user_platform_roles')
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
