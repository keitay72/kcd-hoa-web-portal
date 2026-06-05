import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/address_import_result.dart';
import '../domain/hoa_address.dart';
import '../domain/hoa_address_input.dart';
import 'hoa_address_dto.dart';

class DuplicateHoaAddressException implements Exception {
  const DuplicateHoaAddressException(this.normalizedKey);

  final String normalizedKey;

  @override
  String toString() {
    return 'Address already exists for this HOA: $normalizedKey';
  }
}

abstract interface class AddressRepository {
  Future<List<HoaAddress>> list({String? hoaId});

  Future<HoaAddress> getById(String id);

  Future<HoaAddress> create(HoaAddressInput input);

  Future<HoaAddress> update({
    required String id,
    required HoaAddressInput input,
  });

  Future<AddressImportResult> importCsvRows(List<HoaAddressInput> rows);
}

class SupabaseAddressRepository implements AddressRepository {
  const SupabaseAddressRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns = '''
    id,
    hoa_id,
    line1,
    line2,
    city,
    state,
    postal_code,
    normalized_key,
    is_active,
    created_at,
    updated_at,
    hoa_communities(name, code)
  ''';

  @override
  Future<List<HoaAddress>> list({String? hoaId}) async {
    var query = _client.from('hoa_addresses').select(_selectColumns);

    final rows = hoaId == null || hoaId.isEmpty
        ? await query.order('line1', ascending: true)
        : await query.eq('hoa_id', hoaId).order('line1', ascending: true);

    return rows.map((row) => HoaAddressDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<HoaAddress> getById(String id) async {
    final row = await _client
        .from('hoa_addresses')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return HoaAddressDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaAddress> create(HoaAddressInput input) async {
    await _ensureUnique(input);

    final row = await _client
        .from('hoa_addresses')
        .insert(input.toJson())
        .select(_selectColumns)
        .single();

    return HoaAddressDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaAddress> update({
    required String id,
    required HoaAddressInput input,
  }) async {
    await _ensureUnique(input, excludingAddressId: id);

    final row = await _client
        .from('hoa_addresses')
        .update(input.toJson())
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return HoaAddressDto.fromJson(row).toDomain();
  }

  @override
  Future<AddressImportResult> importCsvRows(List<HoaAddressInput> rows) async {
    var createdCount = 0;
    final failedRows = <AddressImportFailure>[];
    final seenInFile = <String>{};

    for (var index = 0; index < rows.length; index += 1) {
      final input = rows[index];
      final fileKey = '${input.hoaId}|${input.normalizedKey}';

      if (seenInFile.contains(fileKey)) {
        failedRows.add(
          AddressImportFailure(
            rowNumber: index + 2,
            reason: 'Duplicate address in CSV file.',
          ),
        );
        continue;
      }

      seenInFile.add(fileKey);

      try {
        await create(input);
        createdCount += 1;
      } catch (error) {
        failedRows.add(
          AddressImportFailure(
            rowNumber: index + 2,
            reason: error.toString(),
          ),
        );
      }
    }

    return AddressImportResult(
      createdCount: createdCount,
      failedRows: failedRows,
    );
  }

  Future<void> _ensureUnique(
    HoaAddressInput input, {
    String? excludingAddressId,
  }) async {
    var query = _client
        .from('hoa_addresses')
        .select('id')
        .eq('hoa_id', input.hoaId)
        .eq('normalized_key', input.normalizedKey);

    final rows = excludingAddressId == null
        ? await query.limit(1)
        : await query.neq('id', excludingAddressId).limit(1);

    if (rows.isNotEmpty) {
      throw DuplicateHoaAddressException(input.normalizedKey);
    }
  }
}
