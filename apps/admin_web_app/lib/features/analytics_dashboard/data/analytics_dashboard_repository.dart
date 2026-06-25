import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/analytics_dashboard.dart';
import 'analytics_dashboard_dtos.dart';

abstract interface class AnalyticsDashboardRepository {
  Future<AnalyticsDashboardSnapshot> loadSnapshot({
    bool includeLaunchReadiness = true,
  });
}

class SupabaseAnalyticsDashboardRepository
    implements AnalyticsDashboardRepository {
  const SupabaseAnalyticsDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AnalyticsDashboardSnapshot> loadSnapshot({
    bool includeLaunchReadiness = true,
  }) async {
    final results = await Future.wait<Object>([
      _platformMetrics(),
      _ticketMetrics(),
      _operationalMetrics(),
      includeLaunchReadiness
          ? _tenantLaunchReadinessMetrics()
          : Future.value(_emptyLaunchReadinessMetrics),
      _recentTickets(),
      _recentResidentRegistrations(),
      _recentHoaCreations(),
      _recentDocumentUploads(),
    ]);

    return AnalyticsDashboardSnapshot(
      platformMetrics: results[0] as PlatformMetrics,
      ticketMetrics: results[1] as TicketMetricsBreakdown,
      operationalMetrics: results[2] as OperationalMetrics,
      launchReadinessMetrics: results[3] as TenantLaunchReadinessMetrics,
      recentTickets: results[4] as List<RecentTicketActivity>,
      recentResidentRegistrations:
          results[5] as List<RecentResidentRegistration>,
      recentHoaCreations: results[6] as List<RecentHoaCreation>,
      recentDocumentUploads: results[7] as List<RecentDocumentUpload>,
      loadedAt: DateTime.now().toUtc(),
    );
  }

  static const _emptyLaunchReadinessMetrics = TenantLaunchReadinessMetrics(
    totalTenants: 0,
    readyToLaunch: 0,
    launched: 0,
    blocked: 0,
    missingSubscription: 0,
    missingBillingContact: 0,
    missingTenantAdmin: 0,
    missingHoa: 0,
    stripePending: 0,
    overIncludedLimits: 0,
  );

  Future<PlatformMetrics> _platformMetrics() async {
    final now = DateTime.now().toUtc().toIso8601String();

    final results = await Future.wait<int>([
      _countRows(_client.from('hoa_communities').select('id')),
      _activeResidentCount(),
      _countRows(
        _client
            .from('residency_verifications')
            .select('id')
            .eq('status', 'pending'),
      ),
      _countRows(
        _client
            .from('activation_codes')
            .select('id')
            .eq('status', 'active')
            .gt('expires_at', now),
      ),
      _countRows(
          _client.from('documents').select('id').neq('status', 'archived')),
      _countRows(
          _client.from('announcements').select('id').neq('status', 'archived')),
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
      open: (counts['open'] ?? 0) +
          (counts['triaged'] ?? 0) +
          (counts['reopened'] ?? 0),
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

    final tenantRoleRows =
        await _client.from('user_tenant_roles').select('user_id, role_id');
    final tenantRoleCodes = await _roleCodesById(
      tenantRoleRows.map((row) => row['role_id'] as int),
    );

    final communityManagers = <String, String>{};
    final boardContacts = <String, String>{};
    for (final row in hoaRoleRows) {
      final role = row['roles'] as Map<String, dynamic>?;
      final roleCode = role?['code'] as String?;
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      if (roleCode == 'hoa_manager') {
        communityManagers[userId] = 'Community Manager';
      }
      if (roleCode == 'hoa_board') {
        boardContacts[userId] = 'Board Contact';
      }
    }

    final tenantStaff = <String, String>{};
    final customerService = <String, String>{};
    for (final row in tenantRoleRows) {
      final roleCode = tenantRoleCodes[row['role_id'] as int];
      final userId = row['user_id'] as String?;
      if (userId == null) continue;
      final roleLabel = _teamRoleLabel(roleCode);
      if (roleLabel != null) {
        tenantStaff[userId] = roleLabel;
      }
      if (roleCode == 'tenant_csr') {
        customerService[userId] = 'Customer Service';
      }
    }

    final profiles = await _profilesById({
      ...communityManagers.keys,
      ...boardContacts.keys,
      ...tenantStaff.keys,
      ...customerService.keys,
    });

    return OperationalMetrics(
      communityManagers: _teamMembers(communityManagers, profiles),
      boardContacts: _teamMembers(boardContacts, profiles),
      tenantStaffMembers: _teamMembers(tenantStaff, profiles),
      customerServiceMembers: _teamMembers(customerService, profiles),
    );
  }

  String? _teamRoleLabel(String? roleCode) {
    return switch (roleCode) {
      'tenant_owner' => 'Owner',
      'tenant_admin' => 'Admin',
      'tenant_manager' => 'Manager',
      'tenant_csr' => 'Customer Service',
      _ => null,
    };
  }

  Future<Map<String, _TeamProfile>> _profilesById(Set<String> ids) async {
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('profiles')
        .select('id, full_name, email, phone')
        .inFilter('id', ids.toList());

    return {
      for (final row in rows)
        row['id'] as String: _TeamProfile(
          name: row['full_name'] as String?,
          email: row['email'] as String?,
          phone: row['phone'] as String?,
        ),
    };
  }

  List<TeamMemberSummary> _teamMembers(
    Map<String, String> roleByUserId,
    Map<String, _TeamProfile> profiles,
  ) {
    final members = roleByUserId.entries.map((entry) {
      final profile = profiles[entry.key];
      final email = profile?.email?.trim() ?? '';
      final name = profile?.name?.trim();
      return TeamMemberSummary(
        userId: entry.key,
        name: name == null || name.isEmpty
            ? (email.isEmpty ? 'Unknown user' : email)
            : name,
        email: email,
        phone: profile?.phone?.trim(),
        role: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return members;
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

  Future<TenantLaunchReadinessMetrics> _tenantLaunchReadinessMetrics() async {
    final tenantRows = await _client.from('platform_tenants').select(
        'id, tenant_onboarding_status(status, launch_ready_at, launched_at)');
    final tenantIds = tenantRows.map((row) => row['id'] as String).toList();
    if (tenantIds.isEmpty) {
      return const TenantLaunchReadinessMetrics(
        totalTenants: 0,
        readyToLaunch: 0,
        launched: 0,
        blocked: 0,
        missingSubscription: 0,
        missingBillingContact: 0,
        missingTenantAdmin: 0,
        missingHoa: 0,
        stripePending: 0,
        overIncludedLimits: 0,
      );
    }

    final tenantHoaIds = await _hoaIdsByTenant(tenantIds);
    final hoaCounts = {
      for (final entry in tenantHoaIds.entries) entry.key: entry.value.length,
    };
    final residentCounts = await _residentCountsByTenant(tenantHoaIds);
    final billingContactCounts = await _billingContactCountsByTenant(tenantIds);
    final tenantAdminCounts = await _tenantAdminCountsByTenant(tenantIds);
    final subscriptions =
        await _currentSubscriptionSnapshotsByTenant(tenantIds);

    var readyToLaunch = 0;
    var launched = 0;
    var blocked = 0;
    var missingSubscription = 0;
    var missingBillingContact = 0;
    var missingTenantAdmin = 0;
    var missingHoa = 0;
    var stripePending = 0;
    var overIncludedLimits = 0;

    for (final row in tenantRows) {
      final tenantId = row['id'] as String;
      final onboarding = _firstNestedMap(row['tenant_onboarding_status']);
      final onboardingStatus = onboarding?['status'] as String?;
      final hasLaunchReadyAt = onboarding?['launch_ready_at'] != null;
      final hasLaunchedAt = onboarding?['launched_at'] != null;
      final subscription = subscriptions[tenantId];
      final hoaCount = hoaCounts[tenantId] ?? 0;
      final residentCount = residentCounts[tenantId] ?? 0;
      final includedHoaCount = subscription?.includedHoaCount;
      final includedResidentCount = subscription?.includedResidentCount;

      final isLaunched = onboardingStatus == 'launched' || hasLaunchedAt;
      final isReadyToLaunch = !isLaunched &&
          (onboardingStatus == 'ready_to_launch' || hasLaunchReadyAt);
      final isBlocked = onboardingStatus == 'blocked';

      if (isLaunched) {
        launched++;
      } else if (isReadyToLaunch) {
        readyToLaunch++;
      }

      if (isBlocked) {
        blocked++;
      }
      if (subscription == null || subscription.status == 'cancelled') {
        missingSubscription++;
      }
      if ((billingContactCounts[tenantId] ?? 0) == 0) {
        missingBillingContact++;
      }
      if ((tenantAdminCounts[tenantId] ?? 0) == 0) {
        missingTenantAdmin++;
      }
      if (hoaCount == 0) {
        missingHoa++;
      }
      if (subscription != null &&
          subscription.status != 'cancelled' &&
          !subscription.hasStripePrice) {
        stripePending++;
      }
      if ((includedHoaCount != null && hoaCount > includedHoaCount) ||
          (includedResidentCount != null &&
              residentCount > includedResidentCount)) {
        overIncludedLimits++;
      }
    }

    return TenantLaunchReadinessMetrics(
      totalTenants: tenantIds.length,
      readyToLaunch: readyToLaunch,
      launched: launched,
      blocked: blocked,
      missingSubscription: missingSubscription,
      missingBillingContact: missingBillingContact,
      missingTenantAdmin: missingTenantAdmin,
      missingHoa: missingHoa,
      stripePending: stripePending,
      overIncludedLimits: overIncludedLimits,
    );
  }

  Future<Map<String, List<String>>> _hoaIdsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('hoa_communities')
        .select('id, tenant_id')
        .inFilter('tenant_id', tenantIds);
    final hoaIds = <String, List<String>>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      final hoaId = row['id'] as String?;
      if (tenantId == null || hoaId == null) continue;
      hoaIds.putIfAbsent(tenantId, () => <String>[]).add(hoaId);
    }
    return hoaIds;
  }

  Future<Map<String, int>> _residentCountsByTenant(
    Map<String, List<String>> hoaIdsByTenant,
  ) async {
    final allHoaIds = hoaIdsByTenant.values.expand((ids) => ids).toList();
    if (allHoaIds.isEmpty) return const {};

    final tenantByHoaId = <String, String>{};
    for (final entry in hoaIdsByTenant.entries) {
      for (final hoaId in entry.value) {
        tenantByHoaId[hoaId] = entry.key;
      }
    }

    final rows = await _client
        .from('user_hoa_memberships')
        .select('user_id, hoa_id, roles!inner(code)')
        .inFilter('hoa_id', allHoaIds)
        .eq('status', 'active')
        .inFilter('roles.code', ['resident', 'hoa_resident']);

    final residentIdsByTenant = <String, Set<String>>{};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final hoaId = row['hoa_id'] as String?;
      final tenantId = hoaId == null ? null : tenantByHoaId[hoaId];
      if (userId == null || tenantId == null) continue;
      residentIdsByTenant.putIfAbsent(tenantId, () => <String>{}).add(userId);
    }

    return {
      for (final entry in residentIdsByTenant.entries)
        entry.key: entry.value.length,
    };
  }

  Future<Map<String, int>> _billingContactCountsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('tenant_billing_contacts')
        .select('tenant_id')
        .inFilter('tenant_id', tenantIds);
    final counts = <String, int>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      if (tenantId == null) continue;
      counts[tenantId] = (counts[tenantId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _tenantAdminCountsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('user_platform_roles')
        .select('tenant_id, roles!inner(code)')
        .inFilter('tenant_id', tenantIds)
        .inFilter('roles.code', [
      'tenant_owner',
      'tenant_admin',
      'tenant_manager',
      'sys_admin',
      'mgmt'
    ]);
    final counts = <String, int>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      if (tenantId == null) continue;
      counts[tenantId] = (counts[tenantId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, _TenantReadinessSubscriptionSnapshot>>
      _currentSubscriptionSnapshotsByTenant(List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('tenant_subscriptions')
        .select(
          'tenant_id, status, subscription_plans(included_hoa_count, included_resident_count), '
          'subscription_plan_prices(stripe_price_id)',
        )
        .inFilter('tenant_id', tenantIds)
        .order('created_at', ascending: false);
    final subscriptions = <String, _TenantReadinessSubscriptionSnapshot>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String;
      subscriptions.putIfAbsent(
        tenantId,
        () => _TenantReadinessSubscriptionSnapshot.fromJson(row),
      );
    }
    return subscriptions;
  }

  Map<String, dynamic>? _firstNestedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      return first is Map<String, dynamic> ? first : null;
    }
    return null;
  }

  Future<List<RecentTicketActivity>> _recentTickets() async {
    final rows = await _client
        .from('tickets')
        .select(
            'id, subject, status, priority, created_at, hoa_communities(name), profiles(full_name, email)')
        .order('created_at', ascending: false)
        .limit(6);

    return rows
        .map((row) => RecentTicketActivityDto.fromJson(row).toDomain())
        .toList();
  }

  Future<List<RecentResidentRegistration>>
      _recentResidentRegistrations() async {
    final rows = await _client
        .from('residency_verifications')
        .select(
            'id, status, created_at, profiles(full_name, email), hoa_communities(name)')
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

    return rows
        .map((row) => RecentHoaCreationDto.fromJson(row).toDomain())
        .toList();
  }

  Future<List<RecentDocumentUpload>> _recentDocumentUploads() async {
    final rows = await _client
        .from('documents')
        .select(
            'id, title, category, status, created_at, hoa_communities(name)')
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
      if ({'resident', 'hoa_resident'}.contains(roleCode) && userId != null) {
        residentIds.add(userId);
      }
    }

    return residentIds.length;
  }

  Future<int> _countRows(dynamic query) async {
    final rows = await query as List<dynamic>;
    return rows.length;
  }
}

class _TenantReadinessSubscriptionSnapshot {
  const _TenantReadinessSubscriptionSnapshot({
    required this.status,
    required this.hasStripePrice,
    this.includedHoaCount,
    this.includedResidentCount,
  });

  final String status;
  final bool hasStripePrice;
  final int? includedHoaCount;
  final int? includedResidentCount;

  factory _TenantReadinessSubscriptionSnapshot.fromJson(
      Map<String, dynamic> json) {
    final plan = json['subscription_plans'] as Map<String, dynamic>?;
    final price = json['subscription_plan_prices'] as Map<String, dynamic>?;

    return _TenantReadinessSubscriptionSnapshot(
      status: json['status'] as String? ?? 'active',
      hasStripePrice:
          (price?['stripe_price_id'] as String?)?.isNotEmpty ?? false,
      includedHoaCount: plan?['included_hoa_count'] as int?,
      includedResidentCount: plan?['included_resident_count'] as int?,
    );
  }
}

class _TeamProfile {
  const _TeamProfile({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String? name;
  final String? email;
  final String? phone;
}
