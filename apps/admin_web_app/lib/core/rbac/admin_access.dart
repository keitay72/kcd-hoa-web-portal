class AdminRoleAssignment {
  const AdminRoleAssignment({
    required this.code,
    required this.name,
    this.hoaId,
    this.hoaName,
  });

  final String code;
  final String name;
  final String? hoaId;
  final String? hoaName;

  bool get isPlatformWide => hoaId == null;

  String get label {
    if (hoaName == null) return name;
    return '$name - $hoaName';
  }
}

class AdminAccess {
  const AdminAccess({
    required this.userId,
    required this.platformRoles,
    required this.hoaRoles,
    required this.permissions,
  });

  final String userId;
  final List<AdminRoleAssignment> platformRoles;
  final List<AdminRoleAssignment> hoaRoles;
  final Set<String> permissions;

  bool get isSystemAdmin => hasRole('sys_admin');
  bool get hasAnyRole => platformRoles.isNotEmpty || hoaRoles.isNotEmpty;
  bool get hasPlatformRole => platformRoles.isNotEmpty;
  bool get isHoaScopedOnly => !hasPlatformRole && hoaRoles.isNotEmpty;

  List<AdminRoleAssignment> get allRoles => [
        ...platformRoles,
        ...hoaRoles,
      ];

  String get roleSummary {
    if (allRoles.isEmpty) return 'No role assigned';
    final labels = allRoles.map((role) => role.label).toSet().toList()..sort();
    return labels.join(', ');
  }

  bool hasRole(String roleCode) {
    return allRoles.any((role) => role.code == roleCode);
  }

  bool hasAnyRoleCode(Set<String> roleCodes) {
    return allRoles.any((role) => roleCodes.contains(role.code));
  }

  bool can(String permissionCode) {
    return isSystemAdmin || permissions.contains(permissionCode);
  }

  bool canAny(Iterable<String> permissionCodes) {
    return isSystemAdmin || permissionCodes.any(permissions.contains);
  }

  bool canAll(Iterable<String> permissionCodes) {
    return isSystemAdmin || permissionCodes.every(permissions.contains);
  }

  List<String> get hoaScopeIds => hoaRoles.map((role) => role.hoaId).whereType<String>().toSet().toList();

  bool canAccessHoa(String hoaId) {
    return hasPlatformRole || hoaRoles.any((role) => role.hoaId == hoaId);
  }

  bool canManageHoa(String hoaId) {
    if (!canAccessHoa(hoaId)) return false;
    return canAny(const {
      'hoa.manage',
      'addresses.manage',
      'announcements.manage',
      'documents.manage',
      'schedules.manage',
    });
  }
}
