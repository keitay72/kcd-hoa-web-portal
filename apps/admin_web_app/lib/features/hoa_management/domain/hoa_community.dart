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
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final HoaCommunityStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == HoaCommunityStatus.active;
}
