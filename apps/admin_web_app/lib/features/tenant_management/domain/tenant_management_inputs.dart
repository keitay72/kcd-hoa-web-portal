class TenantInput {
  const TenantInput({
    required this.name,
    required this.status,
  });

  final String name;
  final String status;
}

class TenantSettingsInput {
  const TenantSettingsInput({
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

class TenantEmailSettingsInput {
  const TenantEmailSettingsInput({
    required this.provider,
    required this.verificationStatus,
    this.senderDomain,
    this.senderEmail,
    this.replyToEmail,
    this.providerDomainId,
  });

  final String provider;
  final String verificationStatus;
  final String? senderDomain;
  final String? senderEmail;
  final String? replyToEmail;
  final String? providerDomainId;
}

class TenantSmsSettingsInput {
  const TenantSmsSettingsInput({
    required this.status,
    this.twilioSubaccountSid,
    this.twilioMessagingServiceSid,
    this.sendingPhoneNumber,
    this.monthlyMessageLimit,
  });

  final String status;
  final String? twilioSubaccountSid;
  final String? twilioMessagingServiceSid;
  final String? sendingPhoneNumber;
  final int? monthlyMessageLimit;
}

class TenantBillingContactInput {
  const TenantBillingContactInput({
    required this.name,
    required this.email,
    required this.isPrimary,
    this.phone,
  });

  final String name;
  final String email;
  final String? phone;
  final bool isPrimary;
}

class TenantSubscriptionInput {
  const TenantSubscriptionInput({
    required this.status,
    this.planId,
    this.priceId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialEndsAt,
  });

  final String status;
  final String? planId;
  final String? priceId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;
}

class TenantOnboardingInput {
  const TenantOnboardingInput({
    required this.status,
    this.blockedReason,
    this.notes,
    this.kickoffCompletedAt,
    this.launchReadyAt,
    this.launchedAt,
  });

  final String status;
  final String? blockedReason;
  final String? notes;
  final DateTime? kickoffCompletedAt;
  final DateTime? launchReadyAt;
  final DateTime? launchedAt;
}
