import 'package:supabase_flutter/supabase_flutter.dart';

import '../../audit_logs/data/admin_audit_logger.dart';
import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_dtos.dart';

abstract interface class TenantManagementRepository {
  Future<List<PlatformTenant>> listTenants(TenantListFilters filters);

  Future<TenantDetail> getTenantDetail(String tenantId);

  Future<PlatformTenant> createTenant(TenantInput input);

  Future<PlatformTenant> updateTenant({
    required String tenantId,
    required TenantInput input,
  });

  Future<void> updateTenantSettings({
    required String tenantId,
    required TenantSettingsInput input,
  });

  Future<void> updateEmailSettings({
    required String tenantId,
    required TenantEmailSettingsInput input,
  });

  Future<void> updateSmsSettings({
    required String tenantId,
    required TenantSmsSettingsInput input,
  });

  Future<void> saveBillingContact({
    required String tenantId,
    String? contactId,
    required TenantBillingContactInput input,
  });

  Future<void> setAddonStatus({
    required String tenantId,
    required String addonId,
    required String status,
  });

  Future<void> saveSubscription({
    required String tenantId,
    String? subscriptionId,
    required TenantSubscriptionInput input,
  });

  Future<StripeActionResult> createCheckoutSession({
    required String tenantId,
    required String subscriptionId,
  });

  Future<StripeActionResult> syncStripeSubscription({
    required String tenantId,
    required String subscriptionId,
  });

  Future<void> saveOnboardingStatus({
    required String tenantId,
    required TenantOnboardingInput input,
  });

  Future<void> assignTenantStaff({
    required String tenantId,
    required TenantStaffAssignmentInput input,
  });

  Future<void> removeTenantStaff(TenantStaffAssignment assignment);
}

class SupabaseTenantManagementRepository implements TenantManagementRepository {
  const SupabaseTenantManagementRepository(this._client);

  final SupabaseClient _client;

  AdminAuditLogger get _audit => AdminAuditLogger(_client);

  @override
  Future<List<PlatformTenant>> listTenants(TenantListFilters filters) async {
    var query = _client
        .from('platform_tenants')
        .select('*, tenant_onboarding_status(*)');
    if (filters.status != null && filters.status!.isNotEmpty) {
      query = query.eq('status', filters.status!);
    }

    final rows = await query.order('name', ascending: true);
    final tenantIds = rows.map((row) => row['id'] as String).toSet().toList();
    final tenantHoaIds = await _hoaIdsByTenant(tenantIds);
    final hoaCounts = {
      for (final entry in tenantHoaIds.entries) entry.key: entry.value.length,
    };
    final residentCounts = await _residentCountsByTenant(tenantHoaIds);
    final staffCounts = await _tenantAdminCountsByTenant(tenantIds);
    final billingContactCounts = await _billingContactCountsByTenant(tenantIds);
    final subscriptions =
        await _currentSubscriptionSnapshotsByTenant(tenantIds);

    final tenants = rows.map((row) {
      final tenantId = row['id'] as String;
      final subscription = subscriptions[tenantId];
      return PlatformTenantDto(
        json: {
          ...Map<String, dynamic>.from(row),
          'hoa_count': hoaCounts[tenantId] ?? 0,
          'resident_count': residentCounts[tenantId] ?? 0,
          'tenant_admin_count': staffCounts[tenantId] ?? 0,
          'billing_contact_count': billingContactCounts[tenantId] ?? 0,
          'subscription_status': subscription?.status,
          'subscription_plan_name': subscription?.planName,
          'subscription_billing_mode': subscription?.billingMode,
          'subscription_has_stripe_price': subscription?.hasStripePrice,
          'included_hoa_count': subscription?.includedHoaCount,
          'included_resident_count': subscription?.includedResidentCount,
        },
      ).toDomain();
    }).where((tenant) {
      final search = filters.search.trim().toLowerCase();
      final matchesSearch = search.isEmpty ||
          tenant.name.toLowerCase().contains(search) ||
          tenant.code.toLowerCase().contains(search) ||
          (tenant.subscriptionPlanName?.toLowerCase().contains(search) ??
              false);
      if (!matchesSearch) return false;

      return switch (filters.readiness) {
        'needs_setup' => tenant.needsSetup,
        'ready_to_launch' => tenant.isLaunchReady && !tenant.isLaunched,
        'launched' => tenant.isLaunched,
        'blocked' => tenant.isOnboardingBlocked,
        'missing_subscription' => !tenant.hasSubscription,
        'missing_admin' => !tenant.hasTenantAdmin,
        'missing_hoa' => !tenant.hasHoas,
        _ => true,
      };
    }).where((tenant) {
      return switch (filters.subscriptionHealth) {
        'missing_subscription' => !tenant.hasSubscription,
        'over_limits' => tenant.isOverIncludedLimits,
        'approaching_limits' => tenant.isApproachingLimits,
        'stripe_pending' => tenant.hasStripePending,
        _ => true,
      };
    }).where((tenant) {
      return switch (filters.billingReadiness) {
        'missing_subscription' => !tenant.hasSubscription,
        'missing_billing_contact' => !tenant.hasBillingContact,
        'over_limits' => tenant.isOverIncludedLimits,
        'stripe_pending' => tenant.hasStripePending,
        _ => true,
      };
    }).toList();

    return tenants;
  }

  Future<Map<String, List<String>>> _hoaIdsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('hoa_communities')
        .select('id, tenant_id')
        .inFilter('tenant_id', tenantIds);
    final hoaIds = <String, List<String>>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      final hoaId = row['id'] as String?;
      if (tenantId == null || hoaId == null) continue;
      hoaIds.putIfAbsent(tenantId, () => <String>[]).add(hoaId);
    }
    return hoaIds;
  }

  Future<Map<String, int>> _residentCountsByTenant(
    Map<String, List<String>> hoaIdsByTenant,
  ) async {
    final allHoaIds = hoaIdsByTenant.values.expand((ids) => ids).toList();
    if (allHoaIds.isEmpty) return const {};

    final tenantByHoaId = <String, String>{};
    for (final entry in hoaIdsByTenant.entries) {
      for (final hoaId in entry.value) {
        tenantByHoaId[hoaId] = entry.key;
      }
    }

    final rows = await _client
        .from('user_hoa_memberships')
        .select('user_id, hoa_id, roles!inner(code)')
        .inFilter('hoa_id', allHoaIds)
        .eq('status', 'active')
        .inFilter('roles.code', ['resident', 'hoa_resident']);

    final residentIdsByTenant = <String, Set<String>>{};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final hoaId = row['hoa_id'] as String?;
      final tenantId = hoaId == null ? null : tenantByHoaId[hoaId];
      if (userId == null || tenantId == null) continue;
      residentIdsByTenant.putIfAbsent(tenantId, () => <String>{}).add(userId);
    }

    return {
      for (final entry in residentIdsByTenant.entries)
        entry.key: entry.value.length,
    };
  }

  Future<Map<String, int>> _billingContactCountsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('tenant_billing_contacts')
        .select('tenant_id')
        .inFilter('tenant_id', tenantIds);
    final counts = <String, int>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      if (tenantId == null) continue;
      counts[tenantId] = (counts[tenantId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _tenantAdminCountsByTenant(
      List<String> tenantIds) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('user_platform_roles')
        .select('tenant_id, roles!inner(code)')
        .inFilter('tenant_id', tenantIds)
        .inFilter('roles.code', ['tenant_admin', 'tenant_manager']);
    final counts = <String, int>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String?;
      if (tenantId == null) continue;
      counts[tenantId] = (counts[tenantId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, _TenantListSubscriptionSnapshot>>
      _currentSubscriptionSnapshotsByTenant(
    List<String> tenantIds,
  ) async {
    if (tenantIds.isEmpty) return const {};
    final rows = await _client
        .from('tenant_subscriptions')
        .select(
          '*, subscription_plans(code, name, included_hoa_count, included_resident_count), '
          'subscription_plan_prices(stripe_price_id)',
        )
        .inFilter('tenant_id', tenantIds)
        .order('created_at', ascending: false);
    final subscriptions = <String, _TenantListSubscriptionSnapshot>{};
    for (final row in rows) {
      final tenantId = row['tenant_id'] as String;
      subscriptions.putIfAbsent(
        tenantId,
        () => _TenantListSubscriptionSnapshot.fromJson(row),
      );
    }
    return subscriptions;
  }

  @override
  Future<TenantDetail> getTenantDetail(String tenantId) async {
    final tenantRow = await _client
        .from('platform_tenants')
        .select()
        .eq('id', tenantId)
        .single();

    final settingsRow = await _client
        .from('tenant_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();

    final emailSettingsRow = await _client
        .from('tenant_email_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();

    final smsSettingsRow = await _client
        .from('tenant_sms_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();

    final onboardingRow = await _client
        .from('tenant_onboarding_status')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();

    final billingRows = await _client
        .from('tenant_billing_contacts')
        .select()
        .eq('tenant_id', tenantId)
        .order('is_primary', ascending: false)
        .order('name', ascending: true);

    final subscriptionRows = await _client
        .from('tenant_subscriptions')
        .select(
            '*, subscription_plans(code, name), subscription_plan_prices(billing_interval, currency, unit_amount_cents)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    final addonRows = await _client
        .from('tenant_addons')
        .select('*, addon_catalog(code, name, description)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    final catalogRows = await _client
        .from('addon_catalog')
        .select()
        .order('name', ascending: true);

    final availablePlans = await _listAvailablePlans();
    final tenantStaff = await _listTenantStaff(tenantId);
    final assignableUsers = await _listAssignableUsers();
    final tenantHoas = await _listTenantHoas(tenantId);
    final tenantAdminCount = tenantStaff
        .where((staff) =>
            const {'tenant_admin', 'tenant_manager'}.contains(staff.roleCode))
        .length;
    final hoaCount = tenantHoas.length;
    final residentCount =
        await _tenantResidentCount(tenantHoas.map((hoa) => hoa.id).toList());

    return TenantDetail(
      tenant: PlatformTenantDto(json: tenantRow).toDomain(),
      settings: settingsRow == null
          ? null
          : TenantSettingsDto(json: settingsRow).toDomain(),
      emailSettings: emailSettingsRow == null
          ? null
          : TenantEmailSettingsDto(json: emailSettingsRow).toDomain(),
      smsSettings: smsSettingsRow == null
          ? null
          : TenantSmsSettingsDto(json: smsSettingsRow).toDomain(),
      billingContacts: billingRows
          .map((row) => TenantBillingContactDto(json: row).toDomain())
          .toList(),
      subscriptions: subscriptionRows
          .map((row) => TenantSubscriptionSummaryDto(json: row).toDomain())
          .toList(),
      availablePlans: availablePlans,
      enabledAddons: addonRows
          .map((row) => TenantAddonSummaryDto(json: row).toDomain())
          .toList(),
      availableAddons: catalogRows
          .map((row) => AddonCatalogEntryDto(json: row).toDomain())
          .toList(),
      onboardingStatus: onboardingRow == null
          ? null
          : TenantOnboardingStatusDto(json: onboardingRow).toDomain(),
      tenantStaff: tenantStaff,
      assignableUsers: assignableUsers,
      tenantHoas: tenantHoas,
      tenantAdminCount: tenantAdminCount,
      hoaCount: hoaCount,
      residentCount: residentCount,
    );
  }

  @override
  Future<PlatformTenant> createTenant(TenantInput input) async {
    final code = await _availableTenantCode(input.name);
    final row = await _client
        .from('platform_tenants')
        .insert({
          'code': code,
          'name': input.name.trim(),
          'status': input.status,
          'is_primary': false,
        })
        .select()
        .single();

    final tenant = PlatformTenantDto(json: row).toDomain();
    await _createDefaultTenantSettings(tenant.id, tenant.name);
    await _createDefaultOnboardingStatus(tenant.id);
    await _audit.log(
      action: 'tenant.created',
      entityType: 'platform_tenant',
      entityId: tenant.id,
      tenantId: tenant.id,
      afterJson: {
        'code': tenant.code,
        'name': tenant.name,
        'status': tenant.status,
      },
    );
    return tenant;
  }

  @override
  Future<PlatformTenant> updateTenant({
    required String tenantId,
    required TenantInput input,
  }) async {
    final before = await _client
        .from('platform_tenants')
        .select()
        .eq('id', tenantId)
        .maybeSingle();
    final row = await _client
        .from('platform_tenants')
        .update({
          'name': input.name.trim(),
          'status': input.status,
        })
        .eq('id', tenantId)
        .select()
        .single();

    await _audit.log(
      action: 'tenant.updated',
      entityType: 'platform_tenant',
      entityId: tenantId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: Map<String, dynamic>.from(row),
    );

    return PlatformTenantDto(json: row).toDomain();
  }

  @override
  Future<void> updateTenantSettings({
    required String tenantId,
    required TenantSettingsInput input,
  }) async {
    final before = await _client
        .from('tenant_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'support_email': _blankToNull(input.supportEmail),
      'support_phone': _blankToNull(input.supportPhone),
      'logo_url': _blankToNull(input.logoUrl),
      'primary_color': _blankToNull(input.primaryColor),
      'secondary_color': _blankToNull(input.secondaryColor),
      'portal_hostname': _blankToNull(input.portalHostname),
      'email_from_name': _blankToNull(input.emailFromName),
      'email_reply_to': _blankToNull(input.emailReplyTo),
      'resident_activation_codes_required':
          input.residentActivationCodesRequired,
      'timezone': input.timezone.trim().isEmpty
          ? 'America/Chicago'
          : input.timezone.trim(),
    };
    await _client.from('tenant_settings').upsert(
          payload,
          onConflict: 'tenant_id',
        );
    await _audit.log(
      action: 'tenant.settings_updated',
      entityType: 'tenant_settings',
      entityId: tenantId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  @override
  Future<void> updateEmailSettings({
    required String tenantId,
    required TenantEmailSettingsInput input,
  }) async {
    final before = await _client
        .from('tenant_email_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'provider': input.provider,
      'sender_domain': _blankToNull(input.senderDomain),
      'sender_email': _blankToNull(input.senderEmail),
      'reply_to_email': _blankToNull(input.replyToEmail),
      'verification_status': input.verificationStatus,
      'provider_domain_id': _blankToNull(input.providerDomainId),
    };
    await _client.from('tenant_email_settings').upsert(
          payload,
          onConflict: 'tenant_id',
        );
    await _audit.log(
      action: 'tenant.email_settings_updated',
      entityType: 'tenant_email_settings',
      entityId: tenantId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  @override
  Future<void> updateSmsSettings({
    required String tenantId,
    required TenantSmsSettingsInput input,
  }) async {
    final before = await _client
        .from('tenant_sms_settings')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'provider': 'twilio',
      'status': input.status,
      'twilio_subaccount_sid': _blankToNull(input.twilioSubaccountSid),
      'twilio_messaging_service_sid':
          _blankToNull(input.twilioMessagingServiceSid),
      'sending_phone_number': _blankToNull(input.sendingPhoneNumber),
      'monthly_message_limit': input.monthlyMessageLimit,
    };
    await _client.from('tenant_sms_settings').upsert(
          payload,
          onConflict: 'tenant_id',
        );
    await _audit.log(
      action: 'tenant.sms_settings_updated',
      entityType: 'tenant_sms_settings',
      entityId: tenantId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );

    final smsAddonId = await _addonIdForCode('sms_notifications');
    if (smsAddonId == null) return;

    final addonStatus = switch (input.status) {
      'active' => 'enabled',
      'pending' => 'requested',
      'suspended' => 'suspended',
      _ => 'disabled',
    };
    await setAddonStatus(
      tenantId: tenantId,
      addonId: smsAddonId,
      status: addonStatus,
    );
  }

  @override
  Future<void> saveBillingContact({
    required String tenantId,
    String? contactId,
    required TenantBillingContactInput input,
  }) async {
    final before = contactId == null
        ? null
        : await _client
            .from('tenant_billing_contacts')
            .select()
            .eq('id', contactId)
            .maybeSingle();

    if (input.isPrimary) {
      await _client
          .from('tenant_billing_contacts')
          .update({'is_primary': false}).eq('tenant_id', tenantId);
    }

    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'name': input.name.trim(),
      'email': input.email.trim(),
      'phone': _blankToNull(input.phone),
      'is_primary': input.isPrimary,
    };

    String entityId = contactId ?? input.email.trim();
    if (contactId == null) {
      final row = await _client
          .from('tenant_billing_contacts')
          .insert(payload)
          .select('id')
          .single();
      entityId = row['id'] as String? ?? entityId;
    } else {
      await _client
          .from('tenant_billing_contacts')
          .update(payload)
          .eq('id', contactId);
    }

    await _audit.log(
      action: contactId == null
          ? 'tenant.billing_contact_created'
          : 'tenant.billing_contact_updated',
      entityType: 'tenant_billing_contact',
      entityId: entityId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  @override
  Future<void> setAddonStatus({
    required String tenantId,
    required String addonId,
    required String status,
  }) async {
    final before = await _client
        .from('tenant_addons')
        .select()
        .eq('tenant_id', tenantId)
        .eq('addon_id', addonId)
        .maybeSingle();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'addon_id': addonId,
      'status': status,
      'disabled_at':
          status == 'disabled' ? DateTime.now().toIso8601String() : null,
    };
    if (status == 'enabled') {
      payload['enabled_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('tenant_addons').upsert(
          payload,
          onConflict: 'tenant_id,addon_id',
        );
    await _audit.log(
      action: 'tenant.addon_status_updated',
      entityType: 'tenant_addon',
      entityId: '$tenantId:$addonId',
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  @override
  Future<void> saveSubscription({
    required String tenantId,
    String? subscriptionId,
    required TenantSubscriptionInput input,
  }) async {
    final before = subscriptionId == null
        ? null
        : await _client
            .from('tenant_subscriptions')
            .select()
            .eq('id', subscriptionId)
            .maybeSingle();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'plan_id': input.planId,
      'price_id': input.priceId,
      'status': input.status,
      'billing_mode': input.billingMode,
      'free_beta_ends_at': input.freeBetaEndsAt?.toIso8601String(),
      'billing_notes': _blankToNull(input.billingNotes),
      'current_period_start': input.currentPeriodStart?.toIso8601String(),
      'current_period_end': input.currentPeriodEnd?.toIso8601String(),
      'trial_ends_at': input.trialEndsAt?.toIso8601String(),
      'cancelled_at':
          input.status == 'cancelled' ? DateTime.now().toIso8601String() : null,
    };

    String entityId = subscriptionId ?? tenantId;
    if (subscriptionId == null) {
      final row = await _client
          .from('tenant_subscriptions')
          .insert(payload)
          .select('id')
          .single();
      entityId = row['id'] as String? ?? entityId;
    } else {
      await _client
          .from('tenant_subscriptions')
          .update(payload)
          .eq('id', subscriptionId);
    }

    await _audit.log(
      action: subscriptionId == null
          ? 'tenant.subscription_created'
          : 'tenant.subscription_updated',
      entityType: 'tenant_subscription',
      entityId: entityId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  Future<String?> _addonIdForCode(String code) async {
    final row = await _client
        .from('addon_catalog')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<List<SubscriptionPlanSummary>> _listAvailablePlans() async {
    final planRows = await _client
        .from('subscription_plans')
        .select()
        .order('name', ascending: true);
    final priceRows = await _client
        .from('subscription_plan_prices')
        .select()
        .order('billing_interval', ascending: true);

    final pricesByPlan = <String, List<SubscriptionPriceSummary>>{};
    for (final row in priceRows) {
      final price = SubscriptionPriceSummary(
        id: row['id'] as String,
        planId: row['plan_id'] as String,
        billingInterval: row['billing_interval'] as String,
        currency: row['currency'] as String? ?? 'usd',
        unitAmountCents: row['unit_amount_cents'] as int,
        status: row['status'] as String? ?? 'active',
        stripePriceId: _text(row['stripe_price_id']),
      );
      pricesByPlan.putIfAbsent(price.planId, () => []).add(price);
    }

    for (final prices in pricesByPlan.values) {
      prices.sort((a, b) => _billingIntervalRank(a.billingInterval).compareTo(
            _billingIntervalRank(b.billingInterval),
          ));
    }

    final plans = planRows.map((row) {
      final id = row['id'] as String;
      return SubscriptionPlanSummary(
        id: id,
        code: row['code'] as String,
        name: row['name'] as String,
        status: row['status'] as String? ?? 'active',
        description: _text(row['description']),
        includedHoaCount: row['included_hoa_count'] as int?,
        includedResidentCount: row['included_resident_count'] as int?,
        prices: pricesByPlan[id] ?? const [],
      );
    }).toList();

    plans.sort((a, b) => _planRank(a.code).compareTo(_planRank(b.code)));
    return plans;
  }

  int _planRank(String code) {
    return switch (code) {
      'starter' => 0,
      'professional' => 1,
      'enterprise' => 2,
      _ => 99,
    };
  }

  int _billingIntervalRank(String interval) {
    return switch (interval) {
      'monthly' => 0,
      'annual' => 1,
      _ => 99,
    };
  }

  @override
  Future<StripeActionResult> createCheckoutSession({
    required String tenantId,
    required String subscriptionId,
  }) async {
    final response = await _client.functions.invoke(
      'create-tenant-checkout-session',
      body: {
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
      },
    );
    final result = _stripeActionResult(response.data);
    await _audit.log(
      action: 'tenant.checkout_session_requested',
      entityType: 'tenant_subscription',
      entityId: subscriptionId,
      tenantId: tenantId,
      afterJson: {
        'tenant_id': tenantId,
        'success': result.success,
        'message': result.message,
        'checkout_session_id': result.checkoutSessionId,
      },
    );
    return result;
  }

  @override
  Future<StripeActionResult> syncStripeSubscription({
    required String tenantId,
    required String subscriptionId,
  }) async {
    final response = await _client.functions.invoke(
      'sync-tenant-stripe-status',
      body: {
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
      },
    );
    final result = _stripeActionResult(response.data);
    await _audit.log(
      action: 'tenant.subscription_sync_requested',
      entityType: 'tenant_subscription',
      entityId: subscriptionId,
      tenantId: tenantId,
      afterJson: {
        'tenant_id': tenantId,
        'success': result.success,
        'message': result.message,
      },
    );
    return result;
  }

  StripeActionResult _stripeActionResult(dynamic data) {
    final body =
        data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    return StripeActionResult(
      success: body['success'] == true,
      message: body['message']?.toString() ?? 'Stripe action completed.',
      checkoutUrl: body['checkout_url']?.toString(),
      checkoutSessionId: body['checkout_session_id']?.toString(),
    );
  }

  @override
  Future<void> saveOnboardingStatus({
    required String tenantId,
    required TenantOnboardingInput input,
  }) async {
    final before = await _client
        .from('tenant_onboarding_status')
        .select()
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'status': input.status,
      'blocked_reason': _blankToNull(input.blockedReason),
      'notes': _blankToNull(input.notes),
      'beta_status': input.betaStatus,
      'beta_contact_name': _blankToNull(input.betaContactName),
      'beta_contact_email': _blankToNull(input.betaContactEmail),
      'beta_target_launch_date': _dateOnly(input.betaTargetLaunchDate),
      'hoa_data_status': input.hoaDataStatus,
      'known_issues': _blankToNull(input.knownIssues),
      'ready_for_hoa_onboarding': input.readyForHoaOnboarding,
      'kickoff_completed_at': input.kickoffCompletedAt?.toIso8601String(),
      'launch_ready_at': input.launchReadyAt?.toIso8601String(),
      'launched_at': input.launchedAt?.toIso8601String(),
      'updated_by': _client.auth.currentUser?.id,
    };
    if (input.status == 'ready_to_launch' && input.launchReadyAt == null) {
      payload['launch_ready_at'] = now;
    }
    if (input.status == 'launched' && input.launchedAt == null) {
      payload['launched_at'] = now;
    }

    await _client.from('tenant_onboarding_status').upsert(
          payload,
          onConflict: 'tenant_id',
        );
    await _audit.log(
      action: 'tenant.onboarding_updated',
      entityType: 'tenant_onboarding_status',
      entityId: tenantId,
      tenantId: tenantId,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: payload,
    );
  }

  @override
  Future<void> assignTenantStaff({
    required String tenantId,
    required TenantStaffAssignmentInput input,
  }) async {
    final payload = <String, dynamic>{
      'user_id': input.userId,
      'tenant_id': tenantId,
      'role_id': input.roleId,
      'assigned_by': _client.auth.currentUser?.id,
    };
    await _client.from('user_platform_roles').upsert(payload);
    await _audit.log(
      action: 'tenant.staff_assigned',
      entityType: 'user_platform_role',
      entityId: '${input.userId}:$tenantId:${input.roleId}',
      tenantId: tenantId,
      afterJson: payload,
    );
  }

  @override
  Future<void> removeTenantStaff(TenantStaffAssignment assignment) async {
    final before = <String, dynamic>{
      'user_id': assignment.userId,
      'tenant_id': assignment.tenantId,
      'role_id': assignment.roleId,
      'role_code': assignment.roleCode,
      'role_name': assignment.roleName,
    };
    await _client
        .from('user_platform_roles')
        .delete()
        .eq('user_id', assignment.userId)
        .eq('tenant_id', assignment.tenantId)
        .eq('role_id', assignment.roleId);
    await _audit.log(
      action: 'tenant.staff_removed',
      entityType: 'user_platform_role',
      entityId:
          '${assignment.userId}:${assignment.tenantId}:${assignment.roleId}',
      tenantId: assignment.tenantId,
      beforeJson: before,
    );
  }

  Future<List<TenantStaffAssignment>> _listTenantStaff(String tenantId) async {
    final rows = await _client
        .from('user_platform_roles')
        .select(
            'user_id, tenant_id, role_id, created_at, roles!inner(code, name)')
        .eq('tenant_id', tenantId)
        .inFilter('roles.code', [
      'tenant_admin',
      'tenant_manager',
      'tenant_csr',
      'tenant_dispatch',
    ]).order('created_at', ascending: false);

    final userIds =
        rows.map((row) => row['user_id'] as String).toSet().toList();
    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, email, full_name, phone, status')
          .inFilter('id', userIds);
      for (final row in profileRows) {
        profilesById[row['id'] as String] = row;
      }
    }

    return rows
        .map(
          (row) => TenantStaffAssignmentDto(
            json: row,
            profileJson: profilesById[row['user_id'] as String],
          ).toDomain(),
        )
        .toList();
  }

  Future<List<TenantAssignableUser>> _listAssignableUsers() async {
    final rows = await _client
        .from('profiles')
        .select('id, email, full_name, status')
        .neq('status', 'disabled')
        .order('full_name', ascending: true)
        .order('email', ascending: true);

    return rows
        .map((row) => TenantAssignableUserDto(json: row).toDomain())
        .toList();
  }

  Future<List<TenantHoaSummary>> _listTenantHoas(String tenantId) async {
    final rows = await _client
        .from('hoa_communities')
        .select('id, code, name, status, created_at')
        .eq('tenant_id', tenantId)
        .order('name', ascending: true);

    return rows
        .map((row) => TenantHoaSummaryDto(json: row).toDomain())
        .toList();
  }

  Future<int> _tenantResidentCount(List<String> hoaIds) async {
    if (hoaIds.isEmpty) return 0;
    final rows = await _client
        .from('user_hoa_memberships')
        .select('user_id, roles!inner(code)')
        .inFilter('hoa_id', hoaIds)
        .eq('status', 'active')
        .inFilter('roles.code', ['resident', 'hoa_resident']);

    final residentIds = <String>{};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      if (userId != null) residentIds.add(userId);
    }
    return residentIds.length;
  }

  Future<int> _tenantAdminCount(String tenantId) async {
    final rows = await _client
        .from('user_platform_roles')
        .select('role_id, roles!inner(code)')
        .eq('tenant_id', tenantId)
        .inFilter('roles.code', ['tenant_admin', 'tenant_manager']);
    return rows.length;
  }

  Future<int> _tenantHoaCount(String tenantId) async {
    final rows = await _client
        .from('hoa_communities')
        .select('id')
        .eq('tenant_id', tenantId);
    return rows.length;
  }

  Future<void> _createDefaultOnboardingStatus(String tenantId) async {
    await _client.from('tenant_onboarding_status').upsert(
      {
        'tenant_id': tenantId,
        'status': 'not_started',
        'updated_by': _client.auth.currentUser?.id,
      },
      onConflict: 'tenant_id',
    );
  }

  Future<void> _createDefaultTenantSettings(
      String tenantId, String name) async {
    await _client.from('tenant_settings').upsert(
      {
        'tenant_id': tenantId,
        'email_from_name': name,
        'timezone': 'America/Chicago',
        'resident_activation_codes_required': true,
      },
      onConflict: 'tenant_id',
    );
    await _client.from('tenant_email_settings').upsert(
      {'tenant_id': tenantId},
      onConflict: 'tenant_id',
    );
    await _client.from('tenant_sms_settings').upsert(
      {'tenant_id': tenantId},
      onConflict: 'tenant_id',
    );
  }

  Future<String> _availableTenantCode(String tenantName) async {
    final base = _tenantCodeFromName(tenantName);
    final rows = await _client.from('platform_tenants').select('code');
    final existingCodes = rows.map((row) => row['code'] as String).toSet();
    if (!existingCodes.contains(base)) return base;

    var suffix = 2;
    while (existingCodes.contains('${base}_$suffix')) {
      suffix++;
    }
    return '${base}_$suffix';
  }

  String _tenantCodeFromName(String name) {
    final normalized = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'TENANT' : normalized;
  }

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _TenantListSubscriptionSnapshot {
  const _TenantListSubscriptionSnapshot({
    required this.status,
    this.planName,
    this.billingMode,
    this.includedHoaCount,
    this.includedResidentCount,
    this.hasStripePrice = false,
  });

  final String status;
  final String? planName;
  final String? billingMode;
  final int? includedHoaCount;
  final int? includedResidentCount;
  final bool hasStripePrice;

  factory _TenantListSubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    final plan = json['subscription_plans'] as Map<String, dynamic>?;
    final price = json['subscription_plan_prices'] as Map<String, dynamic>?;
    final stripePriceId = price?['stripe_price_id'] as String?;
    return _TenantListSubscriptionSnapshot(
      status: json['status'] as String? ?? 'trialing',
      planName: plan?['name'] as String?,
      billingMode: json['billing_mode'] as String?,
      includedHoaCount: plan?['included_hoa_count'] as int?,
      includedResidentCount: plan?['included_resident_count'] as int?,
      hasStripePrice: (json['billing_mode'] as String?) == 'free_beta' ||
          (stripePriceId != null && stripePriceId.trim().isNotEmpty),
    );
  }
}
