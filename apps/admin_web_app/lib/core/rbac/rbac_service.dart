import 'admin_access.dart';
import 'permission_service.dart';
import 'role_service.dart';

abstract interface class RbacService {
  Future<AdminAccess> accessForUser(String userId);
}

class DefaultRbacService implements RbacService {
  const DefaultRbacService({
    required RoleService roleService,
    required PermissionService permissionService,
  })  : _roleService = roleService,
        _permissionService = permissionService;

  final RoleService _roleService;
  final PermissionService _permissionService;

  @override
  Future<AdminAccess> accessForUser(String userId) async {
    final platformRoles = await _roleService.platformRolesForUser(userId);
    final hoaRoles = await _roleService.hoaRolesForUser(userId);

    final roleCodes = {
      ...platformRoles.map((role) => role.code),
      ...hoaRoles.map((role) => role.code),
    }..remove('unknown');

    final permissions = await _permissionService.permissionCodesForRoles(roleCodes);

    return AdminAccess(
      userId: userId,
      platformRoles: platformRoles,
      hoaRoles: hoaRoles,
      permissions: permissions,
    );
  }
}
