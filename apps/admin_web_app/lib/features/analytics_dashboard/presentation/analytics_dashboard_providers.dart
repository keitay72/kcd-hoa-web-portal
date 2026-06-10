import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/analytics_dashboard_repository.dart';
import '../domain/analytics_dashboard.dart';

final analyticsDashboardRepositoryProvider = Provider<AnalyticsDashboardRepository>((ref) {
  return SupabaseAnalyticsDashboardRepository(ref.watch(supabaseClientProvider));
});

final analyticsDashboardProvider = FutureProvider.autoDispose<AnalyticsDashboardSnapshot>((ref) {
  return ref.watch(analyticsDashboardRepositoryProvider).loadSnapshot();
});
