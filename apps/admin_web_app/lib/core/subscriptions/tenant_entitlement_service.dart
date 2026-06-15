import 'package:supabase_flutter/supabase_flutter.dart';

import 'tenant_entitlements.dart';

abstract interface class TenantEntitlementService {
  Future<TenantSubscriptionEntitlements> entitlementsForTenant(String tenantId);
}

class SupabaseTenantEntitlementService implements TenantEntitlementService {
  const SupabaseTenantEntitlementService(this._client);

  final SupabaseClient _client;

  @override
  Future<TenantSubscriptionEntitlements> entitlementsForTenant(String tenantId) async {
    final subscription = await _client
        .from('tenant_subscriptions')
        .select('status, subscription_plans(code)')
        .eq('tenant_id', tenantId)
        .inFilter('status', _activeSubscriptionStatuses)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final addonRows = await _client
        .from('tenant_addons')
        .select('status, addon_catalog(code)')
        .eq('tenant_id', tenantId)
        .eq('status', 'enabled');

    final plan = subscription?['subscription_plans'] as Map<String, dynamic>?;
    final addonCodes = <String>{};
    for (final row in addonRows) {
      final addon = row['addon_catalog'] as Map<String, dynamic>?;
      final code = addon?['code'] as String?;
      if (code != null && code.trim().isNotEmpty) {
        addonCodes.add(code);
      }
    }

    return TenantSubscriptionEntitlements(
      planCode: plan?['code'] as String?,
      enabledAddonCodes: addonCodes,
    );
  }
}

const _activeSubscriptionStatuses = [
  'trialing',
  'active',
  'past_due',
  'paused',
  'incomplete',
];
