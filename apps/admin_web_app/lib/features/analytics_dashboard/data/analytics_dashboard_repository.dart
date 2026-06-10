import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/analytics_dashboard.dart';
import 'analytics_dashboard_dtos.dart';

abstract interface class AnalyticsDashboardRepository {
  Future<AnalyticsDashboardSnapshot> loadSnapshot();
}

class SupabaseAnalyticsDashboardRepository implements AnalyticsDashboardRepository {
  const SupabaseAnalyticsDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AnalyticsDashboardSnapshot> loadSnapshot() async {
    final results = await Future.wait<Object>([
      _platformMetrics(),
      _ticketMetrics(),
      _operationalMetrics(),
      _recentTickets(),
      _recentResidentRegistrations(),
      _recentHoaCreations(),
      _recentDocumentUploads(),
    ]);

    return AnalyticsDashboardSnapshot(
      platformMetrics: results[0] as PlatformMetrics,
      ticketMetrics: results[1] as TicketMetricsBreakdown,
      operationalMetrics: results[2] as OperationalMetrics,
      recentTickets: results[3] as List<RecentTicketActivity>,
      recentResidentRegistrations: results[4] as List<RecentResidentRegistration>,
      recentHoaCreations: results[5] as List<RecentHoaCreation>,
      recentDocumentUploads: results[6] as List<RecentDocumentUpload>,
      loadedAt: DateTime.now().toUtc(),
    );
  }

  Future<PlatformMetrics> _platformMetrics() async {
    final now = DateTime.now().toUtc().toIso8601String();

    final results = await Future.wait<int>([
      _countRows(_client.from('hoa_communities').select('id')),
      _activeResidentCount(),
      _countRows(
        _client.from('residency_verifications').select('id').eq('status', 'pending'),
      ),
      _countRows(
        _client
            .from('activation_codes')
            .select('id')
            .eq('status', 'active')
            .gt('expires_at', now),
      ),
      _countRows(_client.from('documents').select('id').neq('status', 'archived')),
      _countRows(_client.from('announcements').select('id').neq('status', 'archived')),
    ]);

    return PlatformMetrics(
      totalHoas: results[0],
      activeResidents: results[1],
      pendingResidentVerifications: results[2],
      activeActivationCodes: results[3],
      documentsCount: results[4],
      announcementsCount: results[5],
    );
  }

  Future<TicketMetricsBreakdown> _ticketMetrics() async {
    final rows = await _client.from('tickets').select('status');
    final counts = <String, int>{};

    for (final row in rows) {
      final status = row['status'] as String? ?? 'new';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return TicketMetricsBreakdown(
      newTickets: counts['new'] ?? 0,
      open: (counts['open'] ?? 0) + (counts['triaged'] ?? 0) + (counts['reopened'] ?? 0),
      assigned: counts['assigned'] ?? 0,
      inProgress: counts['in_progress'] ?? 0,
      resolved: counts['resolved'] ?? 0,
      closed: counts['closed'] ?? 0,
    );
  }

  Future<OperationalMetrics> _operationalMetrics() async {
    final hoaRoleRows = await _client
        .from('user_hoa_memberships')
        .select('user_id, status, roles(code)')
        .eq('status', 'active');

    final tenantRoleRows = await _client
        .from('user_tenant_roles')
        .select('user_id, role_id');
    final tenantRoleCodes = await _roleCodesById(
      tenantRoleRows.map((row) => row['role_id'] as int),
    );

    final hoaManagers = <String>{};
    final hoaBoardMembers = <String>{};
    for (final row in hoaRoleRows) {
      final role = row['roles'] as Map<String, dynamic>?;
      final roleCode = role?['code'] as String?;
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      if (roleCode == 'hoa_manager') hoaManagers.add(userId);
      if (roleCode == 'hoa_board') hoaBoardMembers.add(userId);
    }

    final kcStaff = <String>{};
    final dispatchUsers = <String>{};
    final csrUsers = <String>{};
    for (final row in tenantRoleRows) {
      final roleCode = tenantRoleCodes[row['role_id'] as int];
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      if ({
        'tenant_admin',
        'tenant_manager',
        'sys_admin',
        'mgmt',
        'tenant_csr',
        'tenant_dispatch',
      }.contains(roleCode)) {
        kcStaff.add(userId);
      }
      if (roleCode == 'tenant_dispatch') dispatchUsers.add(userId);
      if (roleCode == 'tenant_csr') csrUsers.add(userId);
    }

    return OperationalMetrics(
      hoaManagers: hoaManagers.length,
      hoaBoardMembers: hoaBoardMembers.length,
      kcStaff: kcStaff.length,
      dispatchUsers: dispatchUsers.length,
      csrUsers: csrUsers.length,
    );
  }

  Future<Map<int, String>> _roleCodesById(Iterable<int> roleIds) async {
    final ids = roleIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('roles')
        .select('id, code')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as int: row['code'] as String? ?? 'unknown',
    };
  }

  Future<List<RecentTicketActivity>> _recentTickets() async {
    final rows = await _client
        .from('tickets')
        .select('id, subject, status, priority, created_at, hoa_communities(name), profiles(full_name, email)')
        .order('created_at', ascending: false)
        .limit(6);

    return rows
        .map((row) => RecentTicketActivityDto.fromJson(row).toDomain())
        .toList();
  }

  Future<List<RecentResidentRegistration>> _recentResidentRegistrations() async {
    final rows = await _client
        .from('residency_verifications')
        .select('id, status, created_at, profiles(full_name, email), hoa_communities(name)')
        .order('created_at', ascending: false)
        .limit(6);

    return rows
        .map((row) => RecentResidentRegistrationDto.fromJson(row).toDomain())
        .toList();
  }

  Future<List<RecentHoaCreation>> _recentHoaCreations() async {
    final rows = await _client
        .from('hoa_communities')
        .select('id, name, code, status, created_at')
        .order('created_at', ascending: false)
        .limit(6);

    return rows.map((row) => RecentHoaCreationDto.fromJson(row).toDomain()).toList();
  }

  Future<List<RecentDocumentUpload>> _recentDocumentUploads() async {
    final rows = await _client
        .from('documents')
        .select('id, title, category, status, created_at, hoa_communities(name)')
        .order('created_at', ascending: false)
        .limit(6);

    return rows
        .map((row) => RecentDocumentUploadDto.fromJson(row).toDomain())
        .toList();
  }

  Future<int> _activeResidentCount() async {
    final rows = await _client
        .from('user_hoa_memberships')
        .select('user_id, status, roles(code)')
        .eq('status', 'active');

    final residentIds = <String>{};
    for (final row in rows) {
      final role = row['roles'] as Map<String, dynamic>?;
      final roleCode = role?['code'] as String?;
      final userId = row['user_id'] as String?;
      if (roleCode == 'hoa_resident' && userId != null) residentIds.add(userId);
    }

    return residentIds.length;
  }

  Future<int> _countRows(dynamic query) async {
    final rows = await query as List<dynamic>;
    return rows.length;
  }
}
