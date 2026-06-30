import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/hoa_code_generator.dart';
import '../domain/hoa_community.dart';
import '../domain/hoa_community_input.dart';
import 'hoa_community_dto.dart';

abstract interface class HoaRepository {
  Future<List<HoaCommunity>> list();

  Future<HoaCommunity> getById(String id);

  Future<HoaCommunity> create(HoaCommunityInput input, {String? tenantId});

  Future<HoaCommunity> update({
    required String id,
    required HoaCommunityInput input,
  });

  Future<String> availableCodeForName({
    required String name,
    CommunityType communityType = CommunityType.hoa,
    String? excludingHoaId,
  });
}

class SupabaseHoaRepository implements HoaRepository {
  const SupabaseHoaRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<HoaCommunity>> list() async {
    final rows = await _client
        .from('hoa_communities')
        .select()
        .order('name', ascending: true);

    return rows.map((row) => HoaCommunityDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<HoaCommunity> getById(String id) async {
    final row =
        await _client.from('hoa_communities').select().eq('id', id).single();

    return HoaCommunityDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaCommunity> create(HoaCommunityInput input,
      {String? tenantId}) async {
    final targetTenantId = tenantId ?? await _primaryTenantId();
    final code = await availableCodeForName(
      name: input.name,
      communityType: input.communityType,
    );
    final row = await _client
        .from('hoa_communities')
        .insert(input.toInsertJson(tenantId: targetTenantId, code: code))
        .select()
        .single();

    return HoaCommunityDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaCommunity> update({
    required String id,
    required HoaCommunityInput input,
  }) async {
    final code = await availableCodeForName(
      name: input.name,
      communityType: input.communityType,
      excludingHoaId: id,
    );
    final row = await _client
        .from('hoa_communities')
        .update(input.toUpdateJson(code: code))
        .eq('id', id)
        .select()
        .single();

    return HoaCommunityDto.fromJson(row).toDomain();
  }

  @override
  Future<String> availableCodeForName({
    required String name,
    CommunityType communityType = CommunityType.hoa,
    String? excludingHoaId,
  }) async {
    final rows = await _client.from('hoa_communities').select('id, code');
    final existingCodes = rows
        .where((row) => row['id'] != excludingHoaId)
        .map((row) => row['code'] as String);

    return HoaCodeGenerator.uniqueCodeForName(
      name: name,
      existingCodes: existingCodes,
      communityType: communityType,
    );
  }

  Future<String> _primaryTenantId() async {
    final kcDisposalTenant = await _client
        .from('platform_tenants')
        .select('id')
        .eq('code', 'KC_DISPOSAL')
        .maybeSingle();

    if (kcDisposalTenant != null) {
      return kcDisposalTenant['id'] as String;
    }

    final primaryTenant = await _client
        .from('platform_tenants')
        .select('id')
        .eq('is_primary', true)
        .single();

    return primaryTenant['id'] as String;
  }
}
