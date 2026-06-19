enum HoaCommunityStatus {
  active,
  inactive;

  static HoaCommunityStatus fromDatabase(String value) {
    return HoaCommunityStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HoaCommunityStatus.inactive,
    );
  }
}

class HoaCommunity {
  const HoaCommunity({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.residentActivationCodesRequiredOverride,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final HoaCommunityStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? residentActivationCodesRequiredOverride;

  bool get isActive => status == HoaCommunityStatus.active;

  String get residentActivationCodeSettingLabel {
    return switch (residentActivationCodesRequiredOverride) {
      null => 'Activation codes: tenant default',
      true => 'Activation codes: required',
      false => 'Activation codes: bypassed',
    };
  }
}
