import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rbac/rbac_providers.dart';
import '../supabase/supabase_provider.dart';
import 'tenant_entitlement_service.dart';
import 'tenant_entitlements.dart';

final tenantEntitlementServiceProvider = Provider<TenantEntitlementService>((ref) {
  return SupabaseTenantEntitlementService(ref.watch(supabaseClientProvider));
});

final tenantEntitlementsProvider = FutureProvider.autoDispose
    .family<TenantSubscriptionEntitlements, String>((ref, tenantId) {
  return ref.watch(tenantEntitlementServiceProvider).entitlementsForTenant(tenantId);
});

final adminFeatureEntitlementProvider = FutureProvider.autoDispose
    .family<TenantEntitlementResult, TenantFeature>((ref, feature) async {
  final access = await ref.watch(adminAccessProvider.future);

  if (access.isPlatformOperator) {
    return TenantEntitlementResult(
      feature: feature,
      isEnabled: true,
      sourceLabel: 'Platform access',
    );
  }

  final tenantIds = access.tenantScopeIds;
  if (tenantIds.isEmpty) {
    return TenantEntitlementResult(
      feature: feature,
      isEnabled: false,
      sourceLabel: 'No tenant scope assigned',
    );
  }

  final service = ref.watch(tenantEntitlementServiceProvider);
  TenantEntitlementResult? firstResult;
  for (final tenantId in tenantIds) {
    final entitlements = await service.entitlementsForTenant(tenantId);
    final result = entitlements.entitlementFor(feature);
    firstResult ??= result;
    if (result.isEnabled) return result;
  }

  return firstResult ??
      TenantEntitlementResult(
        feature: feature,
        isEnabled: false,
        sourceLabel: 'No tenant subscription assigned',
      );
});
