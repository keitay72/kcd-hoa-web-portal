import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PermissionService {
  Future<Set<String>> permissionCodesForRoles(Set<String> roleCodes);
}

class SupabasePermissionService implements PermissionService {
  const SupabasePermissionService(this._client);

  final SupabaseClient _client;

  @override
  Future<Set<String>> permissionCodesForRoles(Set<String> roleCodes) async {
    if (roleCodes.isEmpty) return <String>{};

    final rows = await _client
        .from('role_permissions')
        .select('roles(code), permissions(code)');

    final permissionCodes = <String>{};
    for (final row in rows) {
      final role = row['roles'] as Map<String, dynamic>?;
      final permission = row['permissions'] as Map<String, dynamic>?;
      final roleCode = role?['code'] as String?;
      final permissionCode = permission?['code'] as String?;
      if (roleCode == null || permissionCode == null) continue;
      if (roleCodes.contains(roleCode)) permissionCodes.add(permissionCode);
    }

    return permissionCodes;
  }
}
