enum TenantFeature {
  residentPortal,
  documents,
  announcements,
  serviceSchedules,
  tickets,
  activationCodes,
  residentVerification,
  dispatchDashboard,
  advancedTicketManagement,
  analyticsDashboard,
  roleManagement,
  customBranding,
  smsNotifications,
  advertisingPlatform,
  whiteLabelBranding,
  customDomain,
  apiAccess;

  String get label {
    return switch (this) {
      TenantFeature.residentPortal => 'Resident Portal',
      TenantFeature.documents => 'Documents',
      TenantFeature.announcements => 'Announcements',
      TenantFeature.serviceSchedules => 'Service Schedules',
      TenantFeature.tickets => 'Tickets',
      TenantFeature.activationCodes => 'Activation Codes',
      TenantFeature.residentVerification => 'Resident Verification',
      TenantFeature.dispatchDashboard => 'Dispatch Dashboard',
      TenantFeature.advancedTicketManagement => 'Advanced Ticket Management',
      TenantFeature.analyticsDashboard => 'Analytics Dashboard',
      TenantFeature.roleManagement => 'Role Management',
      TenantFeature.customBranding => 'Custom Branding',
      TenantFeature.smsNotifications => 'SMS Notifications',
      TenantFeature.advertisingPlatform => 'Advertising Platform',
      TenantFeature.whiteLabelBranding => 'White Label Branding',
      TenantFeature.customDomain => 'Custom Domain',
      TenantFeature.apiAccess => 'API Access',
    };
  }
}

class TenantEntitlementResult {
  const TenantEntitlementResult({
    required this.feature,
    required this.isEnabled,
    required this.sourceLabel,
  });

  final TenantFeature feature;
  final bool isEnabled;
  final String sourceLabel;
}

class TenantSubscriptionEntitlements {
  const TenantSubscriptionEntitlements({
    required this.planCode,
    required this.enabledAddonCodes,
  });

  final String? planCode;
  final Set<String> enabledAddonCodes;

  bool isEnabled(TenantFeature feature) {
    return entitlementFor(feature).isEnabled;
  }

  TenantEntitlementResult entitlementFor(TenantFeature feature) {
    final planCode = this.planCode;
    if (planCode == null || planCode.isEmpty) {
      return TenantEntitlementResult(
        feature: feature,
        isEnabled: false,
        sourceLabel: 'No plan assigned',
      );
    }

    if (_featuresForPlan(planCode).contains(feature)) {
      return TenantEntitlementResult(
        feature: feature,
        isEnabled: true,
        sourceLabel: _planLabel(planCode),
      );
    }

    final addonCode = _addonCodeForFeature(feature);
    if (addonCode != null && enabledAddonCodes.contains(addonCode)) {
      return TenantEntitlementResult(
        feature: feature,
        isEnabled: true,
        sourceLabel: 'Add-on enabled',
      );
    }

    return TenantEntitlementResult(
      feature: feature,
      isEnabled: false,
      sourceLabel: _addonCodeForFeature(feature) == null ? 'Upgrade required' : 'Add-on not enabled',
    );
  }

  List<TenantEntitlementResult> resultsFor(Iterable<TenantFeature> features) {
    return features.map(entitlementFor).toList(growable: false);
  }

  static const coreFeatures = <TenantFeature>[
    TenantFeature.residentPortal,
    TenantFeature.documents,
    TenantFeature.announcements,
    TenantFeature.serviceSchedules,
    TenantFeature.tickets,
    TenantFeature.activationCodes,
    TenantFeature.residentVerification,
  ];

  static const professionalFeatures = <TenantFeature>[
    ...coreFeatures,
    TenantFeature.dispatchDashboard,
    TenantFeature.advancedTicketManagement,
    TenantFeature.analyticsDashboard,
    TenantFeature.roleManagement,
    TenantFeature.customBranding,
  ];

  static const enterpriseFeatures = <TenantFeature>[
    ...professionalFeatures,
    TenantFeature.apiAccess,
  ];

  static const addonFeatures = <TenantFeature>[
    TenantFeature.smsNotifications,
    TenantFeature.whiteLabelBranding,
    TenantFeature.customDomain,
    TenantFeature.advertisingPlatform,
    TenantFeature.apiAccess,
  ];
}

Set<TenantFeature> _featuresForPlan(String planCode) {
  return switch (planCode) {
    'starter' => TenantSubscriptionEntitlements.coreFeatures.toSet(),
    'professional' => TenantSubscriptionEntitlements.professionalFeatures.toSet(),
    'enterprise' => TenantSubscriptionEntitlements.enterpriseFeatures.toSet(),
    _ => const <TenantFeature>{},
  };
}

String _planLabel(String planCode) {
  return switch (planCode) {
    'starter' => 'Starter plan',
    'professional' => 'Professional plan',
    'enterprise' => 'Enterprise plan',
    _ => 'Current plan',
  };
}

String? _addonCodeForFeature(TenantFeature feature) {
  return switch (feature) {
    TenantFeature.smsNotifications => 'sms_notifications',
    TenantFeature.whiteLabelBranding => 'white_label_branding',
    TenantFeature.customDomain => 'custom_domain',
    TenantFeature.advertisingPlatform => 'advertising_platform',
    TenantFeature.apiAccess => 'api_access',
    _ => null,
  };
}
