import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activation_code.dart';
import '../domain/activation_code_address_option.dart';
import '../domain/activation_code_event.dart';
import '../domain/activation_code_inputs.dart';
import '../domain/generated_activation_code.dart';
import 'activation_code_address_option_dto.dart';
import 'activation_code_dto.dart';
import 'activation_code_event_dto.dart';

class ActiveActivationCodeExistsException implements Exception {
  const ActiveActivationCodeExistsException();

  @override
  String toString() {
    return 'This address already has an active activation code.';
  }
}

abstract interface class ActivationCodeRepository {
  Future<List<ActivationCode>> list({String? status});

  Future<ActivationCode> getById(String id);

  Future<List<ActivationCodeEvent>> eventsForCode(String activationCodeId);

  Future<List<ActivationCodeAddressOption>> addressOptions();

  Future<GeneratedActivationCode> generate(GenerateActivationCodeInput input);

  Future<GeneratedActivationCode> reset(ResetActivationCodeInput input);

  Future<ActivationCode> revoke(RevokeActivationCodeInput input);
}

class SupabaseActivationCodeRepository implements ActivationCodeRepository {
  const SupabaseActivationCodeRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns = '''
    id,
    hoa_id,
    address_id,
    code_hash,
    expires_at,
    consumed_at,
    consumed_by,
    reset_count,
    status,
    created_at,
    updated_at,
    hoa_communities(name, code),
    hoa_addresses(line1, line2, city, state, postal_code)
  ''';

  static const _addressSelectColumns = '''
    id,
    hoa_id,
    line1,
    line2,
    city,
    state,
    postal_code,
    is_active,
    hoa_communities(name, code)
  ''';

  @override
  Future<List<ActivationCode>> list({String? status}) async {
    var query = _client.from('activation_codes').select(_selectColumns);

    final rows = status == null || status.isEmpty
        ? await query.order('created_at', ascending: false)
        : await query.eq('status', status).order('created_at', ascending: false);

    return rows.map((row) => ActivationCodeDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<ActivationCode> getById(String id) async {
    final row = await _client
        .from('activation_codes')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return ActivationCodeDto.fromJson(row).toDomain();
  }

  @override
  Future<List<ActivationCodeEvent>> eventsForCode(String activationCodeId) async {
    final rows = await _client
        .from('activation_code_events')
        .select()
        .eq('activation_code_id', activationCodeId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => ActivationCodeEventDto.fromJson(row).toDomain())
        .toList();
  }

  @override
  Future<List<ActivationCodeAddressOption>> addressOptions() async {
    final rows = await _client
        .from('hoa_addresses')
        .select(_addressSelectColumns)
        .eq('is_active', true)
        .order('line1', ascending: true);

    return rows
        .map((row) => ActivationCodeAddressOptionDto.fromJson(row).toDomain())
        .toList();
  }

  @override
  Future<GeneratedActivationCode> generate(GenerateActivationCodeInput input) async {
    await _ensureNoActiveCodeForAddress(input.addressId);

    final address = await _addressById(input.addressId);
    final code = _generatePlaintextCode();
    final row = await _client
        .from('activation_codes')
        .insert({
          'hoa_id': address.hoaId,
          'address_id': address.id,
          'code_hash': _hashCode(code),
          'expires_at': input.expiresAt.toUtc().toIso8601String(),
          'status': ActivationCodeStatus.active.name,
        })
        .select(_selectColumns)
        .single();

    final activationCode = ActivationCodeDto.fromJson(row).toDomain();
    await _writeEvent(
      activationCodeId: activationCode.id,
      action: ActivationCodeEventAction.created,
      reason: _normalizeReason(input.reason),
    );

    return GeneratedActivationCode(
      code: code,
      activationCode: activationCode,
    );
  }

  @override
  Future<GeneratedActivationCode> reset(ResetActivationCodeInput input) async {
    final existing = await getById(input.activationCodeId);
    await _ensureNoOtherActiveCodeForAddress(
      addressId: existing.addressId,
      activationCodeId: existing.id,
    );

    final code = _generatePlaintextCode();
    final row = await _client
        .from('activation_codes')
        .update({
          'code_hash': _hashCode(code),
          'expires_at': input.expiresAt.toUtc().toIso8601String(),
          'consumed_at': null,
          'consumed_by': null,
          'reset_count': existing.resetCount + 1,
          'status': ActivationCodeStatus.active.name,
        })
        .eq('id', input.activationCodeId)
        .select(_selectColumns)
        .single();

    final activationCode = ActivationCodeDto.fromJson(row).toDomain();
    await _writeEvent(
      activationCodeId: activationCode.id,
      action: ActivationCodeEventAction.reset,
      reason: _normalizeReason(input.reason),
    );

    return GeneratedActivationCode(
      code: code,
      activationCode: activationCode,
    );
  }

  @override
  Future<ActivationCode> revoke(RevokeActivationCodeInput input) async {
    final row = await _client
        .from('activation_codes')
        .update({'status': ActivationCodeStatus.revoked.name})
        .eq('id', input.activationCodeId)
        .select(_selectColumns)
        .single();

    final activationCode = ActivationCodeDto.fromJson(row).toDomain();
    await _writeEvent(
      activationCodeId: activationCode.id,
      action: ActivationCodeEventAction.revoked,
      reason: _normalizeReason(input.reason),
    );

    return activationCode;
  }

  Future<ActivationCodeAddressOption> _addressById(String addressId) async {
    final row = await _client
        .from('hoa_addresses')
        .select(_addressSelectColumns)
        .eq('id', addressId)
        .single();

    return ActivationCodeAddressOptionDto.fromJson(row).toDomain();
  }

  Future<void> _ensureNoActiveCodeForAddress(String addressId) async {
    final rows = await _client
        .from('activation_codes')
        .select('id')
        .eq('address_id', addressId)
        .eq('status', ActivationCodeStatus.active.name)
        .limit(1);

    if (rows.isNotEmpty) {
      throw const ActiveActivationCodeExistsException();
    }
  }

  Future<void> _ensureNoOtherActiveCodeForAddress({
    required String addressId,
    required String activationCodeId,
  }) async {
    final rows = await _client
        .from('activation_codes')
        .select('id')
        .eq('address_id', addressId)
        .eq('status', ActivationCodeStatus.active.name)
        .neq('id', activationCodeId)
        .limit(1);

    if (rows.isNotEmpty) {
      throw const ActiveActivationCodeExistsException();
    }
  }

  Future<void> _writeEvent({
    required String activationCodeId,
    required ActivationCodeEventAction action,
    String? reason,
  }) async {
    await _client.from('activation_code_events').insert({
      'activation_code_id': activationCodeId,
      'action': action.name,
      'actor_user_id': _client.auth.currentUser?.id,
      'reason': reason,
    });
  }

  String _hashCode(String code) {
    return sha256.convert(utf8.encode(code)).toString();
  }

  String _generatePlaintextCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final characters = List.generate(
      10,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();

    return 'KCD-${characters.substring(0, 5)}-${characters.substring(5)}';
  }

  String? _normalizeReason(String? reason) {
    final value = reason?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
