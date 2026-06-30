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

enum CommunityType {
  hoa,
  city;

  static CommunityType fromDatabase(String? value) {
    return CommunityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => CommunityType.hoa,
    );
  }

  String get label {
    return switch (this) {
      CommunityType.hoa => 'HOA',
      CommunityType.city => 'City',
    };
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
    this.communityType = CommunityType.hoa,
    this.city,
    this.state,
    this.residentActivationCodesRequiredOverride,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final HoaCommunityStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommunityType communityType;
  final String? city;
  final String? state;
  final bool? residentActivationCodesRequiredOverride;

  bool get isActive => status == HoaCommunityStatus.active;

  bool get isCity => communityType == CommunityType.city;

  bool get isHoa => communityType == CommunityType.hoa;
}
