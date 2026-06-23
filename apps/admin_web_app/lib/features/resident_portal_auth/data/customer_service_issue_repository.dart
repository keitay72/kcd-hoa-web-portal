import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerServiceIssueAttachmentInput {
  const CustomerServiceIssueAttachmentInput({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get fileSize => bytes.lengthInBytes;
}

class CustomerServiceIssueInput {
  const CustomerServiceIssueInput({
    required this.type,
    required this.subject,
    required this.description,
    this.attachment,
  });

  final String type;
  final String subject;
  final String description;
  final CustomerServiceIssueAttachmentInput? attachment;
}

abstract interface class CustomerServiceIssueRepository {
  Future<String> submit(CustomerServiceIssueInput input);
}

class SupabaseCustomerServiceIssueRepository
    implements CustomerServiceIssueRepository {
  const SupabaseCustomerServiceIssueRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'ticket-attachments';

  @override
  Future<String> submit(CustomerServiceIssueInput input) async {
    final response = await _client.functions.invoke(
      'submit-customer-service-issue',
      body: {
        'type': input.type,
        'subject': input.subject.trim(),
        'description': input.description.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    final ticketId = data['ticketId'] as String;
    final attachment = input.attachment;
    if (attachment != null) {
      await _uploadAttachment(ticketId: ticketId, attachment: attachment);
    }
    return ticketId;
  }

  Future<void> _uploadAttachment({
    required String ticketId,
    required CustomerServiceIssueAttachmentInput attachment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before uploading a service issue photo.');
    }

    final ticket = await _client
        .from('tickets')
        .select('hoa_id')
        .eq('id', ticketId)
        .single();
    final hoaId = ticket['hoa_id'] as String;
    final attachmentId = _uuidV4();
    final storagePath =
        '$hoaId/$ticketId/${_safeFileName(attachment.fileName)}';

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          attachment.bytes,
          fileOptions: FileOptions(
            contentType: attachment.mimeType,
            upsert: false,
          ),
        );

    try {
      await _client.from('ticket_attachments').insert({
        'id': attachmentId,
        'ticket_id': ticketId,
        'uploaded_by': userId,
        'storage_path': storagePath,
        'mime_type': attachment.mimeType,
        'file_size': attachment.fileSize,
        'scan_status': 'pending',
      });
    } catch (_) {
      await _client.storage.from(_bucket).remove([storagePath]);
      rethrow;
    }
  }

  String _safeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'service-issue-photo' : sanitized;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
