class RoleCatalogEntry {
  const RoleCatalogEntry({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final String? description;

  bool get isPlatformRole => const {'sys_admin', 'mgmt', 'csr', 'dispatch'}.contains(code);
  bool get isHoaRole => const {'hoa_manager', 'hoa_board', 'resident'}.contains(code);
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
