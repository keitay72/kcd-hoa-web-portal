import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/analytics_dashboard_repository.dart';
import '../domain/analytics_dashboard.dart';

final analyticsDashboardRepositoryProvider =
    Provider<AnalyticsDashboardRepository>((ref) {
  return SupabaseAnalyticsDashboardRepository(
      ref.watch(supabaseClientProvider));
});

final analyticsDashboardProvider =
    FutureProvider.autoDispose<AnalyticsDashboardSnapshot>((ref) async {
  final access = await ref.watch(activeAdminAccessProvider.future);
  final isTenantScoped =
      access.hasTenantRoleAssignment && !access.hasGlobalRoleAssignment;
  final includeLaunchReadiness = !isTenantScoped || access.isTenantAdmin;

  return ref.watch(analyticsDashboardRepositoryProvider).loadSnapshot(
        includeLaunchReadiness: includeLaunchReadiness,
      );
});
