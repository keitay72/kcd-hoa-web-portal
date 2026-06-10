class RoleCatalogEntry {
  const RoleCatalogEntry({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.roleScope,
    this.lifecycleStatus,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final String? roleScope;
  final String? lifecycleStatus;

  bool get isActive => lifecycleStatus == null || lifecycleStatus == 'active';
  bool get isDeprecated => lifecycleStatus == 'deprecated';

  bool get isGlobalPlatformRole {
    if (roleScope != null) return roleScope == 'platform' && isActive;
    return const {
      'platform_owner',
      'platform_admin',
      'platform_support',
      'platform_sales',
    }.contains(code);
  }

  bool get isTenantRole {
    if (roleScope != null) return roleScope == 'tenant' && isActive;
    return const {'tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch'}.contains(code);
  }

  // Compatibility alias for screens that still assign tenant-scoped staff roles.
  bool get isPlatformRole => isTenantRole;

  bool get isHoaRole {
    if (roleScope != null) return roleScope == 'hoa' && isActive;
    return const {'hoa_manager', 'hoa_board'}.contains(code);
  }

  bool get isResidentRole {
    if (roleScope != null) return roleScope == 'resident' && isActive;
    return code == 'hoa_resident';
  }
}

class PermissionCatalogEntry {
  const PermissionCatalogEntry({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
}

class PlatformTenantOption {
  const PlatformTenantOption({
    required this.id,
    required this.code,
    required this.name,
    required this.isPrimary,
  });

  final String id;
  final String code;
  final String name;
  final bool isPrimary;
}

class HoaScopeOption {
  const HoaScopeOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  String get label => '$name ($code)';
}
