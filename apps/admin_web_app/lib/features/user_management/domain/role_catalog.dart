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
    return const {
      'tenant_owner',
      'tenant_admin',
      'tenant_manager',
      'tenant_csr',
      'tenant_dispatch'
    }.contains(code);
  }

  bool get isHoaRole {
    if (roleScope != null) return roleScope == 'hoa' && isActive;
    return const {'hoa_manager', 'hoa_board'}.contains(code);
  }

  bool get isCommunityRole {
    if (roleScope != null) return roleScope == 'community' && isActive;
    return code == 'community_admin';
  }

  bool get isResidentRole {
    if (roleScope != null) return roleScope == 'resident' && isActive;
    return code == 'hoa_resident';
  }

  bool get canBeInvitedAsPlatformStaff {
    return isGlobalPlatformRole && code != 'platform_owner';
  }

  bool get canBeInvitedAsTenantStaff {
    return isTenantRole &&
        const {
          'tenant_owner',
          'tenant_admin',
          'tenant_manager',
          'tenant_csr',
          'tenant_dispatch',
        }.contains(code);
  }

  bool get canBeInvitedAsCommunityContact {
    return isCommunityRole && code == 'community_admin';
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
