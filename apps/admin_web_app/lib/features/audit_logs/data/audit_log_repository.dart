import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/audit_log.dart';
import 'audit_log_dto.dart';

abstract interface class AuditLogRepository {
  Future<List<AuditLogEntry>> list(AuditLogFilters filters);
  Future<List<AuditHoaOption>> hoaOptions();
}

class SupabaseAuditLogRepository implements AuditLogRepository {
  const SupabaseAuditLogRepository(this._client);

  final SupabaseClient _client;

  static const _select = '''
    id,
    actor_user_id,
    tenant_id,
    hoa_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json,
    ip,
    user_agent,
    created_at
  ''';

  @override
  Future<List<AuditLogEntry>> list(AuditLogFilters filters) async {
    var query = _client.from('admin_audit_logs').select(_select);

    final action = filters.action?.trim();
    if (action != null && action.isNotEmpty) {
      query = query.ilike('action', '%$action%');
    }

    final entityType = filters.entityType?.trim();
    if (entityType != null && entityType.isNotEmpty) {
      query = query.ilike('entity_type', '%$entityType%');
    }

    final hoaId = filters.hoaId?.trim();
    if (hoaId != null && hoaId.isNotEmpty) {
      query = query.eq('hoa_id', hoaId);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(filters.limit.clamp(25, 500) as int);

    final dtos = rows
        .map((row) => AuditLogEntryDto.fromJson(row as Map<String, dynamic>))
        .toList();

    final actors = await _profilesById(dtos.map((item) => item.actorUserId).whereType<String>());
    final tenants = await _tenantsById(dtos.map((item) => item.tenantId).whereType<String>());
    final hoas = await _hoasById(dtos.map((item) => item.hoaId).whereType<String>());

    final entries = dtos.map((dto) {
      final actor = dto.actorUserId == null ? null : actors[dto.actorUserId];
      final tenant = dto.tenantId == null ? null : tenants[dto.tenantId];
      final hoa = dto.hoaId == null ? null : hoas[dto.hoaId];
      return dto.toDomain(
        actorName: actor?.name,
        actorEmail: actor?.email,
        tenantName: tenant?.name,
        tenantCode: tenant?.code,
        hoaName: hoa?.name,
        hoaCode: hoa?.code,
      );
    }).toList();

    final search = filters.search?.trim().toLowerCase();
    if (search == null || search.isEmpty) return entries;

    return entries.where((entry) {
      final haystack = [
        entry.action,
        entry.entityType,
        entry.entityId,
        entry.actorLabel,
        entry.hoaLabel,
        entry.ip ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(search);
    }).toList();
  }

  @override
  Future<List<AuditHoaOption>> hoaOptions() async {
    final rows = await _client
        .from('hoa_communities')
        .select('id, name, code')
        .order('name', ascending: true);

    return rows
        .map((row) => AuditHoaOptionDto.fromJson(row as Map<String, dynamic>).toDomain())
        .toList();
  }

  Future<Map<String, _ProfileLabel>> _profilesById(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return const {};

    final rows = await _client
        .from('profiles')
        .select('id, full_name, email')
        .filter('id', 'in', '(${uniqueIds.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: _ProfileLabel(
          name: row['full_name'] as String?,
          email: row['email'] as String?,
        ),
    };
  }


  Future<Map<String, _TenantLabel>> _tenantsById(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return const {};

    final rows = await _client
        .from('platform_tenants')
        .select('id, name, code')
        .filter('id', 'in', '(${uniqueIds.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: _TenantLabel(
          name: row['name'] as String?,
          code: row['code'] as String?,
        ),
    };
  }

  Future<Map<String, _HoaLabel>> _hoasById(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return const {};

    final rows = await _client
        .from('hoa_communities')
        .select('id, name, code')
        .filter('id', 'in', '(${uniqueIds.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: _HoaLabel(
          name: row['name'] as String?,
          code: row['code'] as String?,
        ),
    };
  }
}

class _ProfileLabel {
  const _ProfileLabel({this.name, this.email});

  final String? name;
  final String? email;
}

class _TenantLabel {
  const _TenantLabel({this.name, this.code});

  final String? name;
  final String? code;
}

class _HoaLabel {
  const _HoaLabel({this.name, this.code});

  final String? name;
  final String? code;
}
