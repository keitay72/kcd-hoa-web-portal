import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Future<List<PlatformTenant>> listTenants(TenantListFilters filters) async {
    var query = _client
        .from('platform_tenants')
        .select('*, tenant_onboarding_status(status, blocked_reason, launch_ready_at, launched_at)');
    if (filters.status != null && filters.status!.isNotEmpty) {
      query = query.eq('status', filters.status!);
    }

    final rows = await query.order('name', ascending: true);
    final tenants = rows
        .map((row) => PlatformTenantDto(json: row).toDomain())
        .where((tenant) {
      final search = filters.search.trim().toLowerCase();
      if (search.isEmpty) return true;
      return tenant.name.toLowerCase().contains(search) ||
          tenant.code.toLowerCase().contains(search);
    }).toList();

    return tenants;
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
        .select('*, subscription_plans(code, name), subscription_plan_prices(billing_interval, currency, unit_amount_cents)')
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
        .where((staff) => const {'tenant_admin', 'tenant_manager', 'sys_admin', 'mgmt'}.contains(staff.roleCode))
        .length;
    final hoaCount = tenantHoas.length;

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
    return tenant;
  }

  @override
  Future<PlatformTenant> updateTenant({
    required String tenantId,
    required TenantInput input,
  }) async {
    final row = await _client
        .from('platform_tenants')
        .update({
          'name': input.name.trim(),
          'status': input.status,
        })
        .eq('id', tenantId)
        .select()
        .single();

    return PlatformTenantDto(json: row).toDomain();
  }

  @override
  Future<void> updateTenantSettings({
    required String tenantId,
    required TenantSettingsInput input,
  }) async {
    await _client.from('tenant_settings').upsert(
      {
        'tenant_id': tenantId,
        'support_email': _blankToNull(input.supportEmail),
        'support_phone': _blankToNull(input.supportPhone),
        'logo_url': _blankToNull(input.logoUrl),
        'primary_color': _blankToNull(input.primaryColor),
        'secondary_color': _blankToNull(input.secondaryColor),
        'portal_hostname': _blankToNull(input.portalHostname),
        'email_from_name': _blankToNull(input.emailFromName),
        'email_reply_to': _blankToNull(input.emailReplyTo),
        'timezone': input.timezone.trim().isEmpty
            ? 'America/Chicago'
            : input.timezone.trim(),
      },
      onConflict: 'tenant_id',
    );
  }

  @override
  Future<void> updateEmailSettings({
    required String tenantId,
    required TenantEmailSettingsInput input,
  }) async {
    await _client.from('tenant_email_settings').upsert(
      {
        'tenant_id': tenantId,
        'provider': input.provider,
        'sender_domain': _blankToNull(input.senderDomain),
        'sender_email': _blankToNull(input.senderEmail),
        'reply_to_email': _blankToNull(input.replyToEmail),
        'verification_status': input.verificationStatus,
        'provider_domain_id': _blankToNull(input.providerDomainId),
      },
      onConflict: 'tenant_id',
    );
  }

  @override
  Future<void> updateSmsSettings({
    required String tenantId,
    required TenantSmsSettingsInput input,
  }) async {
    await _client.from('tenant_sms_settings').upsert(
      {
        'tenant_id': tenantId,
        'provider': 'twilio',
        'status': input.status,
        'twilio_subaccount_sid': _blankToNull(input.twilioSubaccountSid),
        'twilio_messaging_service_sid': _blankToNull(input.twilioMessagingServiceSid),
        'sending_phone_number': _blankToNull(input.sendingPhoneNumber),
        'monthly_message_limit': input.monthlyMessageLimit,
      },
      onConflict: 'tenant_id',
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
    if (input.isPrimary) {
      await _client
          .from('tenant_billing_contacts')
          .update({'is_primary': false})
          .eq('tenant_id', tenantId);
    }

    final payload = {
      'tenant_id': tenantId,
      'name': input.name.trim(),
      'email': input.email.trim(),
      'phone': _blankToNull(input.phone),
      'is_primary': input.isPrimary,
    };

    if (contactId == null) {
      await _client.from('tenant_billing_contacts').insert(payload);
    } else {
      await _client
          .from('tenant_billing_contacts')
          .update(payload)
          .eq('id', contactId);
    }
  }

  @override
  Future<void> setAddonStatus({
    required String tenantId,
    required String addonId,
    required String status,
  }) async {
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'addon_id': addonId,
      'status': status,
      'disabled_at': status == 'disabled' ? DateTime.now().toIso8601String() : null,
    };
    if (status == 'enabled') {
      payload['enabled_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('tenant_addons').upsert(
      payload,
      onConflict: 'tenant_id,addon_id',
    );
  }


  @override
  Future<void> saveSubscription({
    required String tenantId,
    String? subscriptionId,
    required TenantSubscriptionInput input,
  }) async {
    final payload = {
      'tenant_id': tenantId,
      'plan_id': input.planId,
      'price_id': input.priceId,
      'status': input.status,
      'current_period_start': input.currentPeriodStart?.toIso8601String(),
      'current_period_end': input.currentPeriodEnd?.toIso8601String(),
      'trial_ends_at': input.trialEndsAt?.toIso8601String(),
      'cancelled_at': input.status == 'cancelled' ? DateTime.now().toIso8601String() : null,
    };

    if (subscriptionId == null) {
      await _client.from('tenant_subscriptions').insert(payload);
    } else {
      await _client
          .from('tenant_subscriptions')
          .update(payload)
          .eq('id', subscriptionId);
    }
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

    return planRows.map((row) {
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
    return _stripeActionResult(response.data);
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
    return _stripeActionResult(response.data);
  }

  StripeActionResult _stripeActionResult(dynamic data) {
    final body = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
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
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'status': input.status,
      'blocked_reason': _blankToNull(input.blockedReason),
      'notes': _blankToNull(input.notes),
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
  }

  @override
  Future<void> assignTenantStaff({
    required String tenantId,
    required TenantStaffAssignmentInput input,
  }) async {
    await _client.from('user_platform_roles').upsert({
      'user_id': input.userId,
      'tenant_id': tenantId,
      'role_id': input.roleId,
      'assigned_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> removeTenantStaff(TenantStaffAssignment assignment) async {
    await _client
        .from('user_platform_roles')
        .delete()
        .eq('user_id', assignment.userId)
        .eq('tenant_id', assignment.tenantId)
        .eq('role_id', assignment.roleId);
  }

  Future<List<TenantStaffAssignment>> _listTenantStaff(String tenantId) async {
    final rows = await _client
        .from('user_platform_roles')
        .select('user_id, tenant_id, role_id, created_at, roles!inner(code, name)')
        .eq('tenant_id', tenantId)
        .inFilter('roles.code', [
          'tenant_admin',
          'tenant_manager',
          'tenant_csr',
          'tenant_dispatch',
          'sys_admin',
          'mgmt',
          'csr',
          'dispatch',
        ])
        .order('created_at', ascending: false);

    final userIds = rows.map((row) => row['user_id'] as String).toSet().toList();
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

    return rows.map((row) => TenantAssignableUserDto(json: row).toDomain()).toList();
  }

  Future<List<TenantHoaSummary>> _listTenantHoas(String tenantId) async {
    final rows = await _client
        .from('hoa_communities')
        .select('id, code, name, status, created_at')
        .eq('tenant_id', tenantId)
        .order('name', ascending: true);

    return rows.map((row) => TenantHoaSummaryDto(json: row).toDomain()).toList();
  }

  Future<int> _tenantAdminCount(String tenantId) async {
    final rows = await _client
        .from('user_platform_roles')
        .select('role_id, roles!inner(code)')
        .eq('tenant_id', tenantId)
        .inFilter('roles.code', ['tenant_admin', 'tenant_manager', 'sys_admin', 'mgmt']);
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

  Future<void> _createDefaultTenantSettings(String tenantId, String name) async {
    await _client.from('tenant_settings').upsert(
      {
        'tenant_id': tenantId,
        'email_from_name': name,
        'timezone': 'America/Chicago',
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
}

