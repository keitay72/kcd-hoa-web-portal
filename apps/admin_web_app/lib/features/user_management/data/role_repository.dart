import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/role_catalog.dart';
import 'role_catalog_dto.dart';

abstract interface class RoleRepository {
  Future<List<RoleCatalogEntry>> roles();
  Future<List<PermissionCatalogEntry>> permissions();
  Future<List<PlatformTenantOption>> platformTenants();
  Future<List<HoaScopeOption>> hoaCommunities();
}

class SupabaseRoleRepository implements RoleRepository {
  const SupabaseRoleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RoleCatalogEntry>> roles() async {
    final rows = await _client
        .from('roles')
        .select('id, code, name, description, role_scope, lifecycle_status')
        .order('name');

    return rows.map((row) => RoleCatalogEntryDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<List<PermissionCatalogEntry>> permissions() async {
    final rows = await _client
        .from('permissions')
        .select('id, code, name, description')
        .order('code');

    return rows.map((row) => PermissionCatalogEntryDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<List<PlatformTenantOption>> platformTenants() async {
    final rows = await _client
        .from('platform_tenants')
        .select('id, code, name, is_primary')
        .order('is_primary', ascending: false)
        .order('name');

    return rows.map((row) => PlatformTenantOptionDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<List<HoaScopeOption>> hoaCommunities() async {
    final rows = await _client
        .from('hoa_communities')
        .select('id, code, name')
        .eq('status', 'active')
        .order('name');

    return rows.map((row) => HoaScopeOptionDto.fromJson(row).toDomain()).toList();
  }
}
