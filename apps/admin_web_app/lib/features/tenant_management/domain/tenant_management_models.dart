class PlatformTenant {
  const PlatformTenant({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.onboardingStatus,
    this.onboardingBlockedReason,
    this.onboardingLaunchReadyAt,
    this.onboardingLaunchedAt,
    this.betaStatus,
    this.hoaDataStatus,
    this.readyForHoaOnboarding = false,
    this.subscriptionStatus,
    this.subscriptionPlanName,
    this.subscriptionBillingMode,
    this.subscriptionHasStripePrice = false,
    this.hoaCount = 0,
    this.residentCount = 0,
    this.tenantAdminCount = 0,
    this.billingContactCount = 0,
    this.includedHoaCount,
    this.includedResidentCount,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? onboardingStatus;
  final String? onboardingBlockedReason;
  final DateTime? onboardingLaunchReadyAt;
  final DateTime? onboardingLaunchedAt;
  final String? betaStatus;
  final String? hoaDataStatus;
  final bool readyForHoaOnboarding;
  final String? subscriptionStatus;
  final String? subscriptionPlanName;
  final String? subscriptionBillingMode;
  final bool subscriptionHasStripePrice;
  final int hoaCount;
  final int residentCount;
  final int tenantAdminCount;
  final int billingContactCount;
  final int? includedHoaCount;
  final int? includedResidentCount;

  String get onboardingStatusLabel =>
      _titleCase((onboardingStatus ?? 'not_started').replaceAll('_', ' '));
  String get betaStatusLabel =>
      _titleCase((betaStatus ?? 'not_started').replaceAll('_', ' '));
  String get hoaDataStatusLabel =>
      _titleCase((hoaDataStatus ?? 'not_requested').replaceAll('_', ' '));
  String get subscriptionStatusLabel =>
      _titleCase((subscriptionStatus ?? 'not_assigned').replaceAll('_', ' '));
  bool get hasSubscription =>
      subscriptionStatus != null && subscriptionStatus != 'cancelled';
  bool get hasTenantAdmin => tenantAdminCount > 0;
  bool get hasBillingContact => billingContactCount > 0;
  bool get hasHoas => hoaCount > 0;
  bool get hasHoaLimit => includedHoaCount != null;
  bool get hasResidentLimit => includedResidentCount != null;
  bool get isFreeBeta => subscriptionBillingMode == 'free_beta';
  bool get hasStripePending =>
      hasSubscription && !isFreeBeta && !subscriptionHasStripePrice;
  bool get isHoaOverIncluded => hasHoaLimit && hoaCount > includedHoaCount!;
  bool get isResidentOverIncluded =>
      hasResidentLimit && residentCount > includedResidentCount!;
  bool get isOverIncludedLimits => isHoaOverIncluded || isResidentOverIncluded;
  bool get isHoaApproachingLimit =>
      hasHoaLimit && hoaCount >= includedHoaCount! * 0.8 && !isHoaOverIncluded;
  bool get isResidentApproachingLimit =>
      hasResidentLimit &&
      residentCount >= includedResidentCount! * 0.8 &&
      !isResidentOverIncluded;
  bool get isApproachingLimits =>
      isHoaApproachingLimit || isResidentApproachingLimit;
  int get hoaOverageCount => _positiveOverage(hoaCount, includedHoaCount);
  int get residentOverageCount =>
      _positiveOverage(residentCount, includedResidentCount);
  String get subscriptionHealthLabel {
    if (!hasSubscription) return 'No subscription';
    if (isOverIncludedLimits) return 'Over limits';
    if (isApproachingLimits) return 'Approaching limits';
    if (hasStripePending) return 'Stripe pending';
    if (isFreeBeta) return 'Free beta';
    return 'Healthy';
  }

  bool get needsSetup => !isLaunchReady && !isLaunched && !isOnboardingBlocked;
  bool get isOnboardingBlocked => onboardingStatus == 'blocked';
  bool get isLaunchReady =>
      onboardingStatus == 'ready_to_launch' || onboardingLaunchReadyAt != null;
  bool get isLaunched =>
      onboardingStatus == 'launched' || onboardingLaunchedAt != null;

  PlatformTenant copyWith({
    String? onboardingStatus,
    String? onboardingBlockedReason,
    DateTime? onboardingLaunchReadyAt,
    DateTime? onboardingLaunchedAt,
    String? betaStatus,
    String? hoaDataStatus,
    bool? readyForHoaOnboarding,
    String? subscriptionStatus,
    String? subscriptionPlanName,
    String? subscriptionBillingMode,
    bool? subscriptionHasStripePrice,
    int? hoaCount,
    int? residentCount,
    int? tenantAdminCount,
    int? billingContactCount,
    int? includedHoaCount,
    int? includedResidentCount,
  }) {
    return PlatformTenant(
      id: id,
      code: code,
      name: name,
      status: status,
      isPrimary: isPrimary,
      createdAt: createdAt,
      updatedAt: updatedAt,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      onboardingBlockedReason:
          onboardingBlockedReason ?? this.onboardingBlockedReason,
      onboardingLaunchReadyAt:
          onboardingLaunchReadyAt ?? this.onboardingLaunchReadyAt,
      onboardingLaunchedAt: onboardingLaunchedAt ?? this.onboardingLaunchedAt,
      betaStatus: betaStatus ?? this.betaStatus,
      hoaDataStatus: hoaDataStatus ?? this.hoaDataStatus,
      readyForHoaOnboarding:
          readyForHoaOnboarding ?? this.readyForHoaOnboarding,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
      subscriptionBillingMode:
          subscriptionBillingMode ?? this.subscriptionBillingMode,
      subscriptionHasStripePrice:
          subscriptionHasStripePrice ?? this.subscriptionHasStripePrice,
      hoaCount: hoaCount ?? this.hoaCount,
      residentCount: residentCount ?? this.residentCount,
      tenantAdminCount: tenantAdminCount ?? this.tenantAdminCount,
      billingContactCount: billingContactCount ?? this.billingContactCount,
      includedHoaCount: includedHoaCount ?? this.includedHoaCount,
      includedResidentCount:
          includedResidentCount ?? this.includedResidentCount,
    );
  }

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
    this.residentActivationCodesRequired = false,
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
  final bool residentActivationCodesRequired;
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
  String get verificationStatusLabel =>
      _titleCase(verificationStatus.replaceAll('_', ' '));
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

  String get providerLabel => _titleCase(provider.replaceAll('_', ' '));
  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String? get formattedSendingPhoneNumber {
    final digits = sendingPhoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.length != 10) return sendingPhoneNumber;
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
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

class TenantHoaSummary {
  const TenantHoaSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final DateTime? createdAt;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
  bool get isActive => status == 'active';
}

class TenantStaffAssignment {
  const TenantStaffAssignment({
    required this.userId,
    required this.email,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.tenantId,
    required this.createdAt,
    this.fullName,
    this.phone,
    this.status,
  });

  final String userId;
  final String email;
  final String? fullName;
  final String? phone;
  final String? status;
  final int roleId;
  final String roleCode;
  final String roleName;
  final String tenantId;
  final DateTime? createdAt;

  String get displayName {
    final name = fullName?.trim();
    return name == null || name.isEmpty ? email : name;
  }

  String get statusLabel =>
      _titleCase((status ?? 'active').replaceAll('_', ' '));
}

class TenantAssignableUser {
  const TenantAssignableUser({
    required this.id,
    required this.email,
    this.fullName,
    this.status,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? status;

  String get displayName {
    final name = fullName?.trim();
    return name == null || name.isEmpty ? email : name;
  }

  String get label => '$displayName <$email>';
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
    this.includedServiceLocationCount,
    this.serviceLocationOverageCents,
    this.serviceLocationGracePercent,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final List<SubscriptionPriceSummary> prices;
  final String? description;
  final int? includedHoaCount;
  final int? includedResidentCount;
  final int? includedServiceLocationCount;
  final int? serviceLocationOverageCents;
  final int? serviceLocationGracePercent;

  bool get isActive => status == 'active';

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get capacityLabel => includedServiceLocationCount == null
      ? 'Custom customer capacity'
      : '${_formatCount(includedServiceLocationCount!)} customer service locations';

  String get overageLabel {
    if (serviceLocationOverageCents == null) return 'Custom overage pricing';
    final amount = (serviceLocationOverageCents! / 100).toStringAsFixed(2);
    return '\$$amount per extra location/month';
  }

  String get graceLabel =>
      '${serviceLocationGracePercent ?? 0}% usage grace before overage';

  String get limitLabel => '$capacityLabel / $overageLabel';

  List<SubscriptionPriceSummary> get activePrices =>
      prices.where((price) => price.isActive).toList(growable: false);
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

  bool get isActive => status == 'active';
  bool get hasStripePrice =>
      stripePriceId != null && stripePriceId!.trim().isNotEmpty;
  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
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
    this.billingMode = 'manual',
    this.freeBetaEndsAt,
    this.billingNotes,
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
  final String billingMode;
  final DateTime? freeBetaEndsAt;
  final String? billingNotes;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  bool get isFreeBeta => billingMode == 'free_beta';
  bool get isStripeBilling => billingMode == 'stripe';
  bool get isManualBilling => billingMode == 'manual';
  bool get hasPrice => priceId != null;

  String get billingModeLabel => _titleCase(billingMode.replaceAll('_', ' '));

  String get planDisplayName => planName ?? 'No active plan';

  String get priceLabel {
    if (isFreeBeta && (unitAmountCents == null || billingInterval == null)) {
      return 'Free beta / no charge';
    }
    if (unitAmountCents == null || billingInterval == null)
      return 'No price assigned';
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

  bool get isActive => status == 'active';
  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
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
    this.betaStatus = 'not_started',
    this.betaContactName,
    this.betaContactEmail,
    this.betaTargetLaunchDate,
    this.hoaDataStatus = 'not_requested',
    this.knownIssues,
    this.readyForHoaOnboarding = false,
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
  final String betaStatus;
  final String? betaContactName;
  final String? betaContactEmail;
  final DateTime? betaTargetLaunchDate;
  final String hoaDataStatus;
  final String? knownIssues;
  final bool readyForHoaOnboarding;
  final String? updatedBy;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
  String get betaStatusLabel => _titleCase(betaStatus.replaceAll('_', ' '));
  String get hoaDataStatusLabel =>
      _titleCase(hoaDataStatus.replaceAll('_', ' '));
}

class OnboardingChecklistItem {
  const OnboardingChecklistItem({
    required this.label,
    required this.isComplete,
    required this.description,
    required this.action,
    required this.actionLabel,
  });

  final String label;
  final bool isComplete;
  final String description;
  final String action;
  final String actionLabel;
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
    required this.tenantStaff,
    required this.assignableUsers,
    required this.tenantHoas,
    required this.tenantAdminCount,
    required this.hoaCount,
    required this.residentCount,
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
  final List<TenantStaffAssignment> tenantStaff;
  final List<TenantAssignableUser> assignableUsers;
  final List<TenantHoaSummary> tenantHoas;
  final int tenantAdminCount;
  final int hoaCount;
  final int residentCount;

  TenantSubscriptionSummary? get currentSubscription {
    for (final subscription in subscriptions) {
      if (const {'trialing', 'active', 'past_due', 'paused', 'incomplete'}
          .contains(subscription.status)) {
        return subscription;
      }
    }
    return subscriptions.isEmpty ? null : subscriptions.first;
  }

  SubscriptionPlanSummary? get currentPlan {
    final planId = currentSubscription?.planId;
    if (planId == null) return null;
    for (final plan in availablePlans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  int? get hoaLimit => currentPlan?.includedHoaCount;
  int? get residentLimit => currentPlan?.includedResidentCount;

  bool get hasHoaLimit => hoaLimit != null;
  bool get hasResidentLimit => residentLimit != null;

  bool get isHoaLimitReached => hasHoaLimit && hoaCount >= hoaLimit!;
  bool get isResidentLimitReached =>
      hasResidentLimit && residentCount >= residentLimit!;

  bool get isHoaOverLimit => hasHoaLimit && hoaCount > hoaLimit!;
  bool get isResidentOverLimit =>
      hasResidentLimit && residentCount > residentLimit!;

  int get hoaOverageCount => _positiveOverage(hoaCount, hoaLimit);
  int get projectedHoaOverageAfterCreate =>
      _positiveOverage(hoaCount + 1, hoaLimit);
  int get residentOverageCount =>
      _positiveOverage(residentCount, residentLimit);

  int get hoaOverageMonthlyCents => hoaOverageCount * 1000;
  int get projectedHoaOverageMonthlyCentsAfterCreate =>
      projectedHoaOverageAfterCreate * 1000;
  int get residentOverageMonthlyCents => residentOverageCount * 5;

  double? get hoaUsageRatio =>
      hasHoaLimit && hoaLimit! > 0 ? hoaCount / hoaLimit! : null;
  double? get residentUsageRatio => hasResidentLimit && residentLimit! > 0
      ? residentCount / residentLimit!
      : null;

  bool get isHoaUsageWarning {
    final ratio = hoaUsageRatio;
    return ratio != null && ratio >= 0.8 && !isHoaLimitReached;
  }

  bool get isResidentUsageWarning {
    final ratio = residentUsageRatio;
    return ratio != null && ratio >= 0.8 && !isResidentLimitReached;
  }

  List<OnboardingChecklistItem> get onboardingChecklist {
    final currentSubscription = this.currentSubscription;

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
        action: 'edit_tenant',
        actionLabel: 'Review tenant',
      ),
      OnboardingChecklistItem(
        label: 'Subscription assigned',
        isComplete: currentSubscription?.planId != null &&
            (currentSubscription?.priceId != null ||
                currentSubscription?.isFreeBeta == true),
        description:
            currentSubscription?.planName ?? 'Assign a plan and billing mode.',
        action: 'subscription',
        actionLabel:
            currentSubscription == null ? 'Assign plan' : 'Review plan',
      ),
      OnboardingChecklistItem(
        label: 'Billing contact added',
        isComplete: billingContacts.isNotEmpty,
        description: billingContacts.isEmpty
            ? 'Add at least one billing contact.'
            : billingContacts.first.email,
        action: 'billing_contact',
        actionLabel: billingContacts.isEmpty ? 'Add contact' : 'Review contact',
      ),
      OnboardingChecklistItem(
        label: 'Support contact configured',
        isComplete:
            settings?.supportEmail != null || settings?.supportPhone != null,
        description: settings?.supportEmail ??
            settings?.supportPhone ??
            'Add support email or phone.',
        action: 'settings',
        actionLabel: 'Edit support',
      ),
      OnboardingChecklistItem(
        label: 'Email sender configured',
        isComplete: emailSettings?.provider == 'platform_managed' ||
            (emailSettings?.senderEmail != null &&
                emailSettings?.senderDomain != null &&
                emailSettings?.verificationStatus == 'verified'),
        description: emailSettings == null
            ? 'Configure tenant email settings.'
            : emailSettings!.provider == 'platform_managed'
                ? 'Platform Managed sender selected.'
                : emailSettings!.verificationStatus == 'verified'
                    ? emailSettings!.senderEmail ?? 'Tenant sender verified.'
                    : 'Tenant sender requires verified domain setup.',
        action: 'email_settings',
        actionLabel: 'Configure email',
      ),
      OnboardingChecklistItem(
        label: 'SMS decision recorded',
        isComplete: smsAddon == null ||
            smsSettings?.status == 'pending' ||
            smsSettings?.status == 'active',
        description: smsAddon == null
            ? 'SMS add-on is not enabled.'
            : 'SMS status: ${smsSettings?.statusLabel ?? 'Not configured'}',
        action: 'sms_settings',
        actionLabel: 'Review SMS',
      ),
      OnboardingChecklistItem(
        label: 'Tenant owner assigned',
        isComplete: tenantAdminCount > 0,
        description: tenantAdminCount > 0
            ? '$tenantAdminCount tenant owner/admin/manager role(s).'
            : 'Invite or assign a tenant owner.',
        action: 'tenant_owner',
        actionLabel: tenantAdminCount > 0 ? 'Manage staff' : 'Assign owner',
      ),
      OnboardingChecklistItem(
        label: 'First HOA created',
        isComplete: hoaCount > 0,
        description: hoaCount > 0
            ? '$hoaCount HOA community record(s).'
            : "Create the tenant's first HOA.",
        action: 'first_hoa',
        actionLabel: hoaCount > 0 ? 'View HOAs' : 'Create HOA',
      ),
      OnboardingChecklistItem(
        label: 'Marked ready to launch',
        isComplete: onboardingStatus?.launchReadyAt != null ||
            onboardingStatus?.status == 'ready_to_launch' ||
            onboardingStatus?.status == 'launched',
        description: onboardingStatus?.statusLabel ??
            'Mark ready once configuration is complete.',
        action: 'onboarding_status',
        actionLabel: 'Update status',
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
    this.readiness,
    this.subscriptionHealth,
    this.billingReadiness,
  });

  final String search;
  final String? status;
  final String? readiness;
  final String? subscriptionHealth;
  final String? billingReadiness;

  TenantListFilters copyWith({
    String? search,
    String? status,
    String? readiness,
    String? subscriptionHealth,
    String? billingReadiness,
  }) {
    return TenantListFilters(
      search: search ?? this.search,
      status: status,
      readiness: readiness,
      subscriptionHealth: subscriptionHealth,
      billingReadiness: billingReadiness,
    );
  }
}

int _positiveOverage(int current, int? includedLimit) {
  if (includedLimit == null || current <= includedLimit) return 0;
  return current - includedLimit;
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
