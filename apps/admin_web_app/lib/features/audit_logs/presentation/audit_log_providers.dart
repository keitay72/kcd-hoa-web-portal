import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_log.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return SupabaseAuditLogRepository(ref.watch(supabaseClientProvider));
});

final auditLogListProvider = FutureProvider.autoDispose.family<List<AuditLogEntry>, AuditLogFilters>((ref, filters) {
  return ref.watch(auditLogRepositoryProvider).list(filters);
});

final auditHoaOptionsProvider = FutureProvider.autoDispose<List<AuditHoaOption>>((ref) {
  return ref.watch(auditLogRepositoryProvider).hoaOptions();
});
