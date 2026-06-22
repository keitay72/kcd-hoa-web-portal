import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/commercial_catalog_models.dart';

abstract interface class CommercialCatalogRepository {
  Future<List<SubscriptionPlan>> listPlans();

  Future<List<AddonCatalogItem>> listAddons();

  Future<void> savePlan({String? planId, required PlanInput input});

  Future<void> savePrice({
    required String planId,
    String? priceId,
    required PriceInput input,
  });

  Future<void> saveAddon({String? addonId, required AddonInput input});
}

class SupabaseCommercialCatalogRepository
    implements CommercialCatalogRepository {
  const SupabaseCommercialCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    final planRows = await _client
        .from('subscription_plans')
        .select()
        .neq('status', 'archived')
        .order('name', ascending: true);
    final priceRows = await _client
        .from('subscription_plan_prices')
        .select()
        .neq('status', 'archived')
        .order('billing_interval', ascending: true);

    final pricesByPlan = <String, List<SubscriptionPlanPrice>>{};
    for (final row in priceRows) {
      final price = _priceFromRow(row);
      pricesByPlan.putIfAbsent(price.planId, () => []).add(price);
    }

    final plans = planRows.map((row) {
      final id = row['id'] as String;
      return SubscriptionPlan(
        id: id,
        code: row['code'] as String,
        name: row['name'] as String,
        status: row['status'] as String? ?? 'active',
        description: _text(row['description']),
        includedHoaCount: row['included_hoa_count'] as int?,
        includedResidentCount: row['included_resident_count'] as int?,
        includedServiceLocationCount:
            row['included_service_location_count'] as int?,
        serviceLocationOverageCents:
            row['service_location_overage_cents'] as int?,
        serviceLocationGracePercent:
            row['service_location_grace_percent'] as int?,
        prices: pricesByPlan[id] ?? const [],
      );
    }).toList();

    plans.sort((a, b) => _planRank(a.code).compareTo(_planRank(b.code)));
    return plans;
  }

  @override
  Future<List<AddonCatalogItem>> listAddons() async {
    final rows = await _client
        .from('addon_catalog')
        .select()
        .neq('status', 'archived')
        .order('name', ascending: true);

    return rows.map((row) {
      return AddonCatalogItem(
        id: row['id'] as String,
        code: row['code'] as String,
        name: row['name'] as String,
        status: row['status'] as String? ?? 'active',
        description: _text(row['description']),
      );
    }).toList();
  }

  @override
  Future<void> savePlan({String? planId, required PlanInput input}) async {
    final payload = {
      'name': input.name.trim(),
      'status': input.status,
      'description': _blankToNull(input.description),
      'included_hoa_count': null,
      'included_resident_count': null,
      'included_service_location_count': input.includedServiceLocationCount,
      'service_location_overage_cents': input.serviceLocationOverageCents,
      'service_location_grace_percent': input.serviceLocationGracePercent ?? 5,
    };

    if (planId == null) {
      await _client.from('subscription_plans').insert({
        ...payload,
        'code': await _availableCode('subscription_plans', input.name),
      });
    } else {
      await _client.from('subscription_plans').update(payload).eq('id', planId);
    }
  }

  @override
  Future<void> savePrice({
    required String planId,
    String? priceId,
    required PriceInput input,
  }) async {
    final payload = {
      'plan_id': planId,
      'billing_interval': input.billingInterval,
      'currency': input.currency.trim().toLowerCase(),
      'unit_amount_cents': input.unitAmountCents,
      'stripe_price_id': _blankToNull(input.stripePriceId),
      'status': input.status,
    };

    if (priceId == null) {
      await _client.from('subscription_plan_prices').insert(payload);
    } else {
      await _client
          .from('subscription_plan_prices')
          .update(payload)
          .eq('id', priceId);
    }
  }

  @override
  Future<void> saveAddon({String? addonId, required AddonInput input}) async {
    final payload = {
      'name': input.name.trim(),
      'status': input.status,
      'description': _blankToNull(input.description),
    };

    if (addonId == null) {
      await _client.from('addon_catalog').insert({
        ...payload,
        'code': await _availableCode('addon_catalog', input.name),
      });
    } else {
      await _client.from('addon_catalog').update(payload).eq('id', addonId);
    }
  }

  int _planRank(String code) {
    return switch (code) {
      'local' => 0,
      'regional' => 1,
      'metro' => 2,
      'enterprise' => 3,
      _ => 99,
    };
  }

  SubscriptionPlanPrice _priceFromRow(Map<String, dynamic> row) {
    return SubscriptionPlanPrice(
      id: row['id'] as String,
      planId: row['plan_id'] as String,
      billingInterval: row['billing_interval'] as String,
      currency: row['currency'] as String? ?? 'usd',
      unitAmountCents: row['unit_amount_cents'] as int,
      status: row['status'] as String? ?? 'active',
      stripePriceId: _text(row['stripe_price_id']),
    );
  }

  Future<String> _availableCode(String table, String name) async {
    final base = _slug(name);
    final rows = await _client.from(table).select('code');
    final existing = rows.map((row) => row['code'] as String).toSet();
    if (!existing.contains(base)) return base;
    var suffix = 2;
    while (existing.contains('${base}_$suffix')) {
      suffix++;
    }
    return '${base}_$suffix';
  }

  String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'catalog_item' : slug;
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
