import '../domain/role_catalog.dart';

class RoleCatalogEntryDto {
  const RoleCatalogEntryDto({
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

  factory RoleCatalogEntryDto.fromJson(Map<String, dynamic> json) {
    return RoleCatalogEntryDto(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      roleScope: json['role_scope'] as String?,
      lifecycleStatus: json['lifecycle_status'] as String?,
    );
  }

  RoleCatalogEntry toDomain() {
    return RoleCatalogEntry(
      id: id,
      code: code,
      name: name,
      description: description,
      roleScope: roleScope,
      lifecycleStatus: lifecycleStatus,
    );
  }
}

class PermissionCatalogEntryDto {
  const PermissionCatalogEntryDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final String? description;

  factory PermissionCatalogEntryDto.fromJson(Map<String, dynamic> json) {
    return PermissionCatalogEntryDto(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  PermissionCatalogEntry toDomain() {
    return PermissionCatalogEntry(
      id: id,
      code: code,
      name: name,
      description: description,
    );
  }
}

class PlatformTenantOptionDto {
  const PlatformTenantOptionDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isPrimary,
  });

  final String id;
  final String code;
  final String name;
  final bool isPrimary;

  factory PlatformTenantOptionDto.fromJson(Map<String, dynamic> json) {
    return PlatformTenantOptionDto(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  PlatformTenantOption toDomain() {
    return PlatformTenantOption(
      id: id,
      code: code,
      name: name,
      isPrimary: isPrimary,
    );
  }
}

class HoaScopeOptionDto {
  const HoaScopeOptionDto({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  factory HoaScopeOptionDto.fromJson(Map<String, dynamic> json) {
    return HoaScopeOptionDto(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }

  HoaScopeOption toDomain() {
    return HoaScopeOption(id: id, code: code, name: name);
  }
}
