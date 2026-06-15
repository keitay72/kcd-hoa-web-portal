import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/resident_verification.dart';
import 'resident_verification_dto.dart';

abstract interface class ResidentVerificationRepository {
  Future<List<ResidentVerification>> list(ResidentVerificationListFilter filter);

  Future<ResidentVerification> getById(String id);

  Future<List<ResidentAddressMembershipHistory>> historyForUser(String userId);

  Future<ResidentApprovalImpact> approvalImpact(String id);

  Future<ResidentVerification> approve(String id);

  Future<ResidentVerification> reset(String id);

  Future<void> deactivateResident({
    required String userId,
    required String reason,
  });
}

class SupabaseResidentVerificationRepository
    implements ResidentVerificationRepository {
  const SupabaseResidentVerificationRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns = '''
    id,
    user_id,
    hoa_id,
    address_id,
    address_verified,
    email_verified,
    activation_code_verified,
    status,
    verified_at,
    created_at,
    updated_at,
    profiles(email, full_name, phone, status),
    hoa_communities(name, code),
    hoa_addresses(line1, line2, city, state, postal_code)
  ''';

  static const _historySelectColumns = '''
    id,
    user_id,
    hoa_id,
    address_id,
    occupancy_type,
    is_primary,
    is_current,
    start_date,
    end_date,
    created_by,
    created_at,
    updated_at,
    hoa_communities(name, code),
    hoa_addresses(line1, line2, city, state, postal_code)
  ''';

  @override
  Future<List<ResidentVerification>> list(
    ResidentVerificationListFilter filter,
  ) async {
    var query = _client.from('residency_verifications').select(_selectColumns);

    final rows = filter.status == null || filter.status!.isEmpty
        ? await query.order('created_at', ascending: false)
        : await query
            .eq('status', filter.status!)
            .order('created_at', ascending: false);

    final items = rows
        .map((row) => ResidentVerificationDto.fromJson(row).toDomain())
        .toList();

    return items.where((item) => item.matchesSearch(filter.search)).toList();
  }

  @override
  Future<ResidentVerification> getById(String id) async {
    final row = await _client
        .from('residency_verifications')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return ResidentVerificationDto.fromJson(row).toDomain();
  }

  @override
  Future<List<ResidentAddressMembershipHistory>> historyForUser(
    String userId,
  ) async {
    final rows = await _client
        .from('user_address_memberships')
        .select(_historySelectColumns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => ResidentAddressMembershipHistoryDto.fromJson(row).toDomain())
        .toList();
  }

  @override
  Future<ResidentApprovalImpact> approvalImpact(String id) async {
    final verification = await _client
        .from('residency_verifications')
        .select('user_id, hoa_id')
        .eq('id', id)
        .single();

    final userId = verification['user_id'] as String;
    final hoaId = verification['hoa_id'] as String;
    final hoa = await _client
        .from('hoa_communities')
        .select('tenant_id')
        .eq('id', hoaId)
        .single();

    final tenantId = hoa['tenant_id'] as String?;
    if (tenantId == null) {
      return const ResidentApprovalImpact(
        tenantName: 'Unknown tenant',
        planName: 'No active plan',
        currentResidentCount: 0,
        projectedResidentCount: 0,
        willIncreaseResidentCount: false,
      );
    }

    final tenant = await _client
        .from('platform_tenants')
        .select('name')
        .eq('id', tenantId)
        .maybeSingle();

    final subscription = await _client
        .from('tenant_subscriptions')
        .select('id, status, subscription_plans(name, included_resident_count)')
        .eq('tenant_id', tenantId)
        .inFilter('status', ['trialing', 'active', 'past_due', 'paused', 'incomplete'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final plan = subscription?['subscription_plans'] as Map<String, dynamic>?;
    final residentLimit = plan?['included_resident_count'] as int?;
    final planName = plan?['name'] as String? ?? 'No active plan';

    final tenantHoaRows = await _client
        .from('hoa_communities')
        .select('id')
        .eq('tenant_id', tenantId);
    final tenantHoaIds = tenantHoaRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList();

    final residentIds = <String>{};
    var userAlreadyActive = false;
    if (tenantHoaIds.isNotEmpty) {
      final membershipRows = await _client
          .from('user_hoa_memberships')
          .select('user_id, roles!inner(code)')
          .inFilter('hoa_id', tenantHoaIds)
          .eq('status', 'active')
          .inFilter('roles.code', ['resident', 'hoa_resident']);

      for (final row in membershipRows) {
        final residentId = row['user_id'] as String?;
        if (residentId == null) continue;
        residentIds.add(residentId);
        if (residentId == userId) userAlreadyActive = true;
      }
    }

    final currentResidentCount = residentIds.length;
    final willIncreaseResidentCount = !userAlreadyActive;
    final projectedResidentCount =
        currentResidentCount + (willIncreaseResidentCount ? 1 : 0);

    return ResidentApprovalImpact(
      tenantName: tenant?['name'] as String? ?? tenantId,
      planName: planName,
      currentResidentCount: currentResidentCount,
      projectedResidentCount: projectedResidentCount,
      willIncreaseResidentCount: willIncreaseResidentCount,
      residentLimit: residentLimit,
    );
  }

  @override
  Future<ResidentVerification> approve(String id) async {
    final row = await _client
        .from('residency_verifications')
        .update({
          'address_verified': true,
          'email_verified': true,
          'activation_code_verified': true,
          'status': ResidentVerificationStatus.verified.name,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return ResidentVerificationDto.fromJson(row).toDomain();
  }

  @override
  Future<ResidentVerification> reset(String id) async {
    final row = await _client
        .from('residency_verifications')
        .update({
          'address_verified': false,
          'email_verified': false,
          'activation_code_verified': false,
          'status': ResidentVerificationStatus.pending.name,
          'verified_at': null,
        })
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return ResidentVerificationDto.fromJson(row).toDomain();
  }

  @override
  Future<void> deactivateResident({
    required String userId,
    required String reason,
  }) async {
    await _client.from('profiles').update({'status': 'disabled'}).eq('id', userId);

    await _client
        .from('user_address_memberships')
        .update({
          'is_current': false,
          'end_date': DateTime.now().toUtc().toIso8601String().substring(0, 10),
        })
        .eq('user_id', userId)
        .eq('is_current', true);
  }
}
