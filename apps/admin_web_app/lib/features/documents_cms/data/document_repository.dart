import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/hoa_document.dart';
import '../domain/hoa_document_inputs.dart';
import 'hoa_document_dto.dart';

abstract interface class DocumentRepository {
  Future<List<HoaDocument>> list({
    String? hoaId,
    String? status,
    String? category,
  });

  Future<HoaDocument> getById(String id);

  Future<HoaDocument> upload(HoaDocumentUploadInput input);

  Future<HoaDocument> update({
    required String id,
    required HoaDocumentEditInput input,
  });

  Future<HoaDocument> archive(String id);

  Future<String> createDownloadUrl(HoaDocument document);
}

class SupabaseDocumentRepository implements DocumentRepository {
  const SupabaseDocumentRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'hoa-documents';
  static const _selectColumns = '''
    id,
    hoa_id,
    title,
    category,
    storage_path,
    mime_type,
    file_size,
    visibility_scope,
    status,
    created_by,
    created_at,
    updated_at,
    hoa_communities(name, code)
  ''';

  @override
  Future<List<HoaDocument>> list({
    String? hoaId,
    String? status,
    String? category,
  }) async {
    var query = _client.from('documents').select(_selectColumns);

    if (hoaId != null && hoaId.isNotEmpty) {
      query = query.eq('hoa_id', hoaId);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    final rows = await query.order('created_at', ascending: false);
    return rows.map((row) => HoaDocumentDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<HoaDocument> getById(String id) async {
    final row = await _client
        .from('documents')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return HoaDocumentDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaDocument> upload(HoaDocumentUploadInput input) async {
    final documentId = _uuidV4();
    final storagePath = '${input.hoaId}/$documentId/${_safeFileName(input.fileName)}';

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          input.bytes,
          fileOptions: FileOptions(
            contentType: input.mimeType,
            upsert: false,
          ),
        );

    try {
      final row = await _client
          .from('documents')
          .insert({
            'id': documentId,
            'hoa_id': input.hoaId,
            'title': input.title.trim(),
            'category': input.category.trim(),
            'storage_path': storagePath,
            'mime_type': input.mimeType,
            'file_size': input.fileSize,
            'visibility_scope': input.visibilityScope.name,
            'status': HoaDocumentStatus.active.name,
            'created_by': _client.auth.currentUser?.id,
          })
          .select(_selectColumns)
          .single();

      return HoaDocumentDto.fromJson(row).toDomain();
    } catch (_) {
      await _client.storage.from(_bucket).remove([storagePath]);
      rethrow;
    }
  }

  @override
  Future<HoaDocument> update({
    required String id,
    required HoaDocumentEditInput input,
  }) async {
    final row = await _client
        .from('documents')
        .update({
          'title': input.title.trim(),
          'category': input.category.trim(),
          'visibility_scope': input.visibilityScope.name,
          'status': input.status.name,
        })
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return HoaDocumentDto.fromJson(row).toDomain();
  }

  @override
  Future<HoaDocument> archive(String id) async {
    final row = await _client
        .from('documents')
        .update({'status': HoaDocumentStatus.archived.name})
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return HoaDocumentDto.fromJson(row).toDomain();
  }

  @override
  Future<String> createDownloadUrl(HoaDocument document) {
    return _client.storage.from(_bucket).createSignedUrl(
          document.storagePath,
          60 * 10,
        );
  }

  String _safeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'document' : sanitized;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
