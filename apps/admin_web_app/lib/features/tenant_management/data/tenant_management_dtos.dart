import '../domain/tenant_management_models.dart';

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class PlatformTenantDto {
  const PlatformTenantDto({required this.json});

  final Map<String, dynamic> json;

  PlatformTenant toDomain() {
    return PlatformTenant(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'active',
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class TenantSettingsDto {
  const TenantSettingsDto({required this.json});

  final Map<String, dynamic> json;

  TenantSettings toDomain() {
    return TenantSettings(
      tenantId: json['tenant_id'] as String,
      supportEmail: _text(json['support_email']),
      supportPhone: _text(json['support_phone']),
      logoUrl: _text(json['logo_url']),
      primaryColor: _text(json['primary_color']),
      secondaryColor: _text(json['secondary_color']),
      portalHostname: _text(json['portal_hostname']),
      emailFromName: _text(json['email_from_name']),
      emailReplyTo: _text(json['email_reply_to']),
      timezone: json['timezone'] as String? ?? 'America/Chicago',
    );
  }
}

class TenantEmailSettingsDto {
  const TenantEmailSettingsDto({required this.json});

  final Map<String, dynamic> json;

  TenantEmailSettings toDomain() {
    return TenantEmailSettings(
      tenantId: json['tenant_id'] as String,
      provider: json['provider'] as String? ?? 'platform_managed',
      verificationStatus: json['verification_status'] as String? ?? 'not_configured',
      senderDomain: _text(json['sender_domain']),
      senderEmail: _text(json['sender_email']),
      replyToEmail: _text(json['reply_to_email']),
      providerDomainId: _text(json['provider_domain_id']),
      lastVerifiedAt: _date(json['last_verified_at']),
    );
  }
}

class TenantSmsSettingsDto {
  const TenantSmsSettingsDto({required this.json});

  final Map<String, dynamic> json;

  TenantSmsSettings toDomain() {
    return TenantSmsSettings(
      tenantId: json['tenant_id'] as String,
      provider: json['provider'] as String? ?? 'twilio',
      status: json['status'] as String? ?? 'disabled',
      twilioSubaccountSid: _text(json['twilio_subaccount_sid']),
      twilioMessagingServiceSid: _text(json['twilio_messaging_service_sid']),
      sendingPhoneNumber: _text(json['sending_phone_number']),
      monthlyMessageLimit: json['monthly_message_limit'] as int?,
    );
  }
}

class TenantBillingContactDto {
  const TenantBillingContactDto({required this.json});

  final Map<String, dynamic> json;

  TenantBillingContact toDomain() {
    return TenantBillingContact(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: _text(json['phone']),
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class AddonCatalogEntryDto {
  const AddonCatalogEntryDto({required this.json});

  final Map<String, dynamic> json;

  AddonCatalogEntry toDomain() {
    return AddonCatalogEntry(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'active',
      description: _text(json['description']),
    );
  }
}

class TenantAddonSummaryDto {
  const TenantAddonSummaryDto({required this.json});

  final Map<String, dynamic> json;

  TenantAddonSummary toDomain() {
    final addon = json['addon_catalog'] as Map<String, dynamic>? ?? const {};
    return TenantAddonSummary(
      tenantId: json['tenant_id'] as String,
      addonId: json['addon_id'] as String,
      status: json['status'] as String? ?? 'enabled',
      addonName: addon['name'] as String? ?? 'Add-on',
      addonCode: addon['code'] as String? ?? '',
      addonDescription: _text(addon['description']),
      enabledAt: _date(json['enabled_at']),
      disabledAt: _date(json['disabled_at']),
    );
  }
}

class TenantSubscriptionSummaryDto {
  const TenantSubscriptionSummaryDto({required this.json});

  final Map<String, dynamic> json;

  TenantSubscriptionSummary toDomain() {
    final plan = json['subscription_plans'] as Map<String, dynamic>?;
    final price = json['subscription_plan_prices'] as Map<String, dynamic>?;
    return TenantSubscriptionSummary(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      status: json['status'] as String? ?? 'trialing',
      planId: json['plan_id'] as String?,
      priceId: json['price_id'] as String?,
      planName: _text(plan?['name']),
      planCode: _text(plan?['code']),
      billingInterval: _text(price?['billing_interval']),
      currency: _text(price?['currency']),
      unitAmountCents: price?['unit_amount_cents'] as int?,
      currentPeriodStart: _date(json['current_period_start']),
      currentPeriodEnd: _date(json['current_period_end']),
      trialEndsAt: _date(json['trial_ends_at']),
    );
  }
}

class TenantOnboardingStatusDto {
  const TenantOnboardingStatusDto({required this.json});

  final Map<String, dynamic> json;

  TenantOnboardingStatus toDomain() {
    return TenantOnboardingStatus(
      tenantId: json['tenant_id'] as String,
      status: json['status'] as String? ?? 'not_started',
      ownerUserId: _text(json['owner_user_id']),
      kickoffCompletedAt: _date(json['kickoff_completed_at']),
      launchReadyAt: _date(json['launch_ready_at']),
      launchedAt: _date(json['launched_at']),
      blockedReason: _text(json['blocked_reason']),
      notes: _text(json['notes']),
      updatedBy: _text(json['updated_by']),
    );
  }
}
