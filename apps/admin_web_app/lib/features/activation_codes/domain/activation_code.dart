enum ActivationCodeStatus {
  active,
  consumed,
  expired,
  revoked;

  static ActivationCodeStatus fromDatabase(String value) {
    return ActivationCodeStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ActivationCodeStatus.revoked,
    );
  }
}

class ActivationCode {
  const ActivationCode({
    required this.id,
    required this.hoaId,
    required this.addressId,
    required this.codeHash,
    required this.expiresAt,
    this.consumedAt,
    this.consumedBy,
    required this.resetCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
    this.addressLine1,
    this.addressLine2,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
  });

  final String id;
  final String hoaId;
  final String addressId;
  final String codeHash;
  final DateTime expiresAt;
  final DateTime? consumedAt;
  final String? consumedBy;
  final int resetCount;
  final ActivationCodeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  bool get isActive => status == ActivationCodeStatus.active;

  String get statusLabel => status.name[0].toUpperCase() + status.name.substring(1);

  String get addressLabel {
    return <String?>[
      addressLine1,
      addressLine2,
      addressCity,
      addressState,
      addressPostalCode,
    ]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}
