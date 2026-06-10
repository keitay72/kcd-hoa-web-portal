class PlatformTenant {
  const PlatformTenant({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
}

class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    this.supportEmail,
    this.supportPhone,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.portalHostname,
    this.emailFromName,
    this.emailReplyTo,
    this.timezone = 'America/Chicago',
  });

  final String tenantId;
  final String? supportEmail;
  final String? supportPhone;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? portalHostname;
  final String? emailFromName;
  final String? emailReplyTo;
  final String timezone;
}

class TenantEmailSettings {
  const TenantEmailSettings({
    required this.tenantId,
    required this.provider,
    required this.verificationStatus,
    this.senderDomain,
    this.senderEmail,
    this.replyToEmail,
    this.providerDomainId,
    this.lastVerifiedAt,
  });

  final String tenantId;
  final String provider;
  final String verificationStatus;
  final String? senderDomain;
  final String? senderEmail;
  final String? replyToEmail;
  final String? providerDomainId;
  final DateTime? lastVerifiedAt;

  String get providerLabel => _titleCase(provider.replaceAll('_', ' '));
  String get verificationStatusLabel => _titleCase(verificationStatus.replaceAll('_', ' '));
}

class TenantSmsSettings {
  const TenantSmsSettings({
    required this.tenantId,
    required this.provider,
    required this.status,
    this.twilioSubaccountSid,
    this.twilioMessagingServiceSid,
    this.sendingPhoneNumber,
    this.monthlyMessageLimit,
  });

  final String tenantId;
  final String provider;
  final String status;
  final String? twilioSubaccountSid;
  final String? twilioMessagingServiceSid;
  final String? sendingPhoneNumber;
  final int? monthlyMessageLimit;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
}

class TenantBillingContact {
  const TenantBillingContact({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.isPrimary,
    this.phone,
  });

  final String id;
  final String tenantId;
  final String name;
  final String email;
  final String? phone;
  final bool isPrimary;
}

class SubscriptionPlanSummary {
  const SubscriptionPlanSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    this.prices = const [],
    this.description,
    this.includedHoaCount,
    this.includedResidentCount,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final List<SubscriptionPriceSummary> prices;
  final String? description;
  final int? includedHoaCount;
  final int? includedResidentCount;
}

class SubscriptionPriceSummary {
  const SubscriptionPriceSummary({
    required this.id,
    required this.planId,
    required this.billingInterval,
    required this.currency,
    required this.unitAmountCents,
    required this.status,
    this.stripePriceId,
  });

  final String id;
  final String planId;
  final String billingInterval;
  final String currency;
  final int unitAmountCents;
  final String status;
  final String? stripePriceId;

  String get priceLabel {
    final amount = (unitAmountCents / 100).toStringAsFixed(2);
    return '\$$amount/$billingInterval';
  }
}

class TenantSubscriptionSummary {
  const TenantSubscriptionSummary({
    required this.id,
    required this.tenantId,
    required this.status,
    this.planId,
    this.priceId,
    this.planName,
    this.planCode,
    this.billingInterval,
    this.currency,
    this.unitAmountCents,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialEndsAt,
  });

  final String id;
  final String tenantId;
  final String status;
  final String? planId;
  final String? priceId;
  final String? planName;
  final String? planCode;
  final String? billingInterval;
  final String? currency;
  final int? unitAmountCents;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get priceLabel {
    if (unitAmountCents == null || billingInterval == null) return 'No price assigned';
    final amount = (unitAmountCents! / 100).toStringAsFixed(2);
    return '\$$amount/$billingInterval';
  }
}

class AddonCatalogEntry {
  const AddonCatalogEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final String? description;
}

class TenantAddonSummary {
  const TenantAddonSummary({
    required this.tenantId,
    required this.addonId,
    required this.status,
    required this.addonName,
    required this.addonCode,
    this.addonDescription,
    this.enabledAt,
    this.disabledAt,
  });

  final String tenantId;
  final String addonId;
  final String status;
  final String addonName;
  final String addonCode;
  final String? addonDescription;
  final DateTime? enabledAt;
  final DateTime? disabledAt;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
}

class TenantOnboardingStatus {
  const TenantOnboardingStatus({
    required this.tenantId,
    required this.status,
    this.ownerUserId,
    this.kickoffCompletedAt,
    this.launchReadyAt,
    this.launchedAt,
    this.blockedReason,
    this.notes,
    this.updatedBy,
  });

  final String tenantId;
  final String status;
  final String? ownerUserId;
  final DateTime? kickoffCompletedAt;
  final DateTime? launchReadyAt;
  final DateTime? launchedAt;
  final String? blockedReason;
  final String? notes;
  final String? updatedBy;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
}

class OnboardingChecklistItem {
  const OnboardingChecklistItem({
    required this.label,
    required this.isComplete,
    required this.description,
  });

  final String label;
  final bool isComplete;
  final String description;
}

class TenantDetail {
  const TenantDetail({
    required this.tenant,
    required this.settings,
    required this.emailSettings,
    required this.smsSettings,
    required this.billingContacts,
    required this.subscriptions,
    required this.availablePlans,
    required this.availableAddons,
    required this.enabledAddons,
    required this.onboardingStatus,
    required this.tenantAdminCount,
    required this.hoaCount,
  });

  final PlatformTenant tenant;
  final TenantSettings? settings;
  final TenantEmailSettings? emailSettings;
  final TenantSmsSettings? smsSettings;
  final List<TenantBillingContact> billingContacts;
  final List<TenantSubscriptionSummary> subscriptions;
  final List<SubscriptionPlanSummary> availablePlans;
  final List<AddonCatalogEntry> availableAddons;
  final List<TenantAddonSummary> enabledAddons;
  final TenantOnboardingStatus? onboardingStatus;
  final int tenantAdminCount;
  final int hoaCount;

  List<OnboardingChecklistItem> get onboardingChecklist {
    TenantSubscriptionSummary? currentSubscription;
    for (final subscription in subscriptions) {
      if (const {'trialing', 'active', 'past_due', 'paused', 'incomplete'}
          .contains(subscription.status)) {
        currentSubscription = subscription;
        break;
      }
    }
    currentSubscription ??= subscriptions.isEmpty ? null : subscriptions.first;

    TenantAddonSummary? smsAddon;
    for (final addon in enabledAddons) {
      if (addon.addonCode == 'sms_notifications' &&
          const {'requested', 'enabled'}.contains(addon.status)) {
        smsAddon = addon;
        break;
      }
    }

    return [
      OnboardingChecklistItem(
        label: 'Tenant created',
        isComplete: true,
        description: tenant.name,
      ),
      OnboardingChecklistItem(
        label: 'Subscription assigned',
        isComplete: currentSubscription?.planId != null && currentSubscription?.priceId != null,
        description: currentSubscription?.planName ?? 'Assign a plan and rate.',
      ),
      OnboardingChecklistItem(
        label: 'Billing contact added',
        isComplete: billingContacts.isNotEmpty,
        description: billingContacts.isEmpty ? 'Add at least one billing contact.' : billingContacts.first.email,
      ),
      OnboardingChecklistItem(
        label: 'Support contact configured',
        isComplete: settings?.supportEmail != null || settings?.supportPhone != null,
        description: settings?.supportEmail ?? settings?.supportPhone ?? 'Add support email or phone.',
      ),
      OnboardingChecklistItem(
        label: 'Email sender configured',
        isComplete: emailSettings?.provider == 'platform_managed' || emailSettings?.senderEmail != null,
        description: emailSettings?.senderEmail ?? emailSettings?.providerLabel ?? 'Configure tenant email settings.',
      ),
      OnboardingChecklistItem(
        label: 'SMS decision recorded',
        isComplete: smsAddon == null || smsSettings?.status == 'pending' || smsSettings?.status == 'active',
        description: smsAddon == null ? 'SMS add-on is not enabled.' : 'SMS status: ${smsSettings?.statusLabel ?? 'Not configured'}',
      ),
      OnboardingChecklistItem(
        label: 'Tenant admin assigned',
        isComplete: tenantAdminCount > 0,
        description: tenantAdminCount > 0 ? '$tenantAdminCount tenant admin/manager role(s).' : 'Invite or assign a tenant admin.',
      ),
      OnboardingChecklistItem(
        label: 'First HOA created',
        isComplete: hoaCount > 0,
        description: hoaCount > 0 ? '$hoaCount HOA community record(s).' : "Create the tenant's first HOA.",
      ),
      OnboardingChecklistItem(
        label: 'Marked ready to launch',
        isComplete: onboardingStatus?.launchReadyAt != null || onboardingStatus?.status == 'ready_to_launch' || onboardingStatus?.status == 'launched',
        description: onboardingStatus?.statusLabel ?? 'Mark ready once configuration is complete.',
      ),
    ];
  }

  int get onboardingCompletedCount {
    return onboardingChecklist.where((item) => item.isComplete).length;
  }

  int get onboardingTotalCount => onboardingChecklist.length;

  double get onboardingProgress {
    if (onboardingTotalCount == 0) return 0;
    return onboardingCompletedCount / onboardingTotalCount;
  }

  TenantAddonSummary? addonFor(String addonId) {
    for (final addon in enabledAddons) {
      if (addon.addonId == addonId) return addon;
    }
    return null;
  }
}

class StripeActionResult {
  const StripeActionResult({
    required this.success,
    required this.message,
    this.checkoutUrl,
    this.checkoutSessionId,
  });

  final bool success;
  final String message;
  final String? checkoutUrl;
  final String? checkoutSessionId;
}

class TenantListFilters {
  const TenantListFilters({
    this.search = '',
    this.status,
  });

  final String search;
  final String? status;

  TenantListFilters copyWith({String? search, String? status}) {
    return TenantListFilters(
      search: search ?? this.search,
      status: status,
    );
  }
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
