import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rbac/unauthorized_page.dart';
import 'subscription_providers.dart';
import 'tenant_entitlements.dart';

class ProtectedTenantFeaturePage extends ConsumerWidget {
  const ProtectedTenantFeaturePage({
    required this.feature,
    required this.child,
    super.key,
  });

  final TenantFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(adminFeatureEntitlementProvider(feature));
    return entitlement.when(
      data: (result) {
        if (result.isEnabled) return child;
        return UnauthorizedPage(
          message: '${feature.label} is not available for this tenant. ${result.sourceLabel}.',
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => UnauthorizedPage(
        message: 'Unable to verify ${feature.label} access: $error',
      ),
    );
  }
}

extension ProtectedTenantFeature on Widget {
  Widget protectedByFeature(TenantFeature feature) {
    return ProtectedTenantFeaturePage(feature: feature, child: this);
  }
}
