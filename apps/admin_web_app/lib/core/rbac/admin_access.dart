class AdminRoleAssignment {
  const AdminRoleAssignment({
    required this.code,
    required this.name,
    this.tenantId,
    this.tenantName,
    this.hoaId,
    this.hoaName,
  });

  final String code;
  final String name;
  final String? tenantId;
  final String? tenantName;
  final String? hoaId;
  final String? hoaName;

  bool get isGlobalPlatformRole => tenantId == null && hoaId == null;
  bool get isTenantScoped => tenantId != null && hoaId == null;
  bool get isHoaScoped => hoaId != null;

  String get label {
    if (hoaName != null) return '$name - $hoaName';
    if (tenantName != null) return '$name - $tenantName';
    return name;
  }
}

class AdminAccess {
  const AdminAccess({
    required this.userId,
    required this.globalRoles,
    required this.tenantRoles,
    required this.hoaRoles,
    required this.permissions,
  });

  final String userId;
  final List<AdminRoleAssignment> globalRoles;
  final List<AdminRoleAssignment> tenantRoles;
  final List<AdminRoleAssignment> hoaRoles;
  final Set<String> permissions;

  // Compatibility alias while older admin screens are migrated from
  // platform-role terminology to tenant-role terminology.
  List<AdminRoleAssignment> get platformRoles => tenantRoles;

  bool get isPlatformOwner => hasGlobalRole('platform_owner');
  bool get isPlatformAdmin => hasGlobalRole('platform_admin');
  bool get isPlatformSupport => hasGlobalRole('platform_support');
  bool get isPlatformSales => hasGlobalRole('platform_sales');
  bool get isPlatformOperator => globalRoles.isNotEmpty;

  bool get isTenantAdmin => hasTenantRole('tenant_admin');
  bool get isTenantManager => hasTenantRole('tenant_manager');
  bool get isTenantStaff => tenantRoles.isNotEmpty;

  bool get isSystemAdmin => isPlatformOwner || isPlatformAdmin;
  bool get hasAnyRole => allRoles.isNotEmpty;
  bool get hasGlobalRoleAssignment => globalRoles.isNotEmpty;
  bool get hasTenantRoleAssignment => tenantRoles.isNotEmpty;
  bool get hasPlatformRole => hasGlobalRoleAssignment || hasTenantRoleAssignment;
  bool get isHoaScopedOnly => !hasPlatformRole && hoaRoles.isNotEmpty;

  List<AdminRoleAssignment> get allRoles => [
        ...globalRoles,
        ...tenantRoles,
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

  bool hasGlobalRole(String roleCode) {
    return globalRoles.any((role) => role.code == roleCode);
  }

  bool hasTenantRole(String roleCode) {
    return tenantRoles.any((role) => role.code == roleCode);
  }

  bool hasHoaRole(String roleCode) {
    return hoaRoles.any((role) => role.code == roleCode);
  }

  bool hasAnyRoleCode(Set<String> roleCodes) {
    return allRoles.any((role) => roleCodes.contains(role.code));
  }

  bool can(String permissionCode) {
    return isPlatformOwner || isPlatformAdmin || permissions.contains(permissionCode);
  }

  bool canAny(Iterable<String> permissionCodes) {
    return isPlatformOwner || isPlatformAdmin || permissionCodes.any(permissions.contains);
  }

  bool canAll(Iterable<String> permissionCodes) {
    return isPlatformOwner || isPlatformAdmin || permissionCodes.every(permissions.contains);
  }

  List<String> get tenantScopeIds => tenantRoles.map((role) => role.tenantId).whereType<String>().toSet().toList();
  List<String> get hoaScopeIds => hoaRoles.map((role) => role.hoaId).whereType<String>().toSet().toList();

  bool canAccessTenant(String tenantId) {
    return isPlatformOperator || tenantRoles.any((role) => role.tenantId == tenantId);
  }

  bool canAccessHoa(String hoaId) {
    return isPlatformOperator || isTenantStaff || hoaRoles.any((role) => role.hoaId == hoaId);
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
