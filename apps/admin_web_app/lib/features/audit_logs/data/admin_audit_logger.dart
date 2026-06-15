import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuditLogger {
  const AdminAuditLogger(this._client);

  final SupabaseClient _client;

  Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    String? tenantId,
    String? hoaId,
    Map<String, dynamic>? beforeJson,
    Map<String, dynamic>? afterJson,
  }) async {
    final normalizedEntityId = entityId.trim().isEmpty ? 'unknown' : entityId.trim();

    try {
      await _client.from('admin_audit_logs').insert({
        'actor_user_id': _client.auth.currentUser?.id,
        'tenant_id': tenantId,
        'hoa_id': hoaId,
        'action': action,
        'entity_type': entityType,
        'entity_id': normalizedEntityId,
        'before_json': beforeJson,
        'after_json': afterJson,
      });
    } catch (_) {
      // Admin actions should not fail only because the audit insert failed.
      // RLS and Edge Function logs remain the system of record for privileged paths.
    }
  }
}
