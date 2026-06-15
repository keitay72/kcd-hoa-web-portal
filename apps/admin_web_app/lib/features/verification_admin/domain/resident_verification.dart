enum ResidentVerificationStatus {
  pending,
  verified,
  failed;

  static ResidentVerificationStatus fromDatabase(String value) {
    return ResidentVerificationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ResidentVerificationStatus.pending,
    );
  }
}

class ResidentVerificationListFilter {
  const ResidentVerificationListFilter({
    this.status,
    this.search = '',
  });

  final String? status;
  final String search;

  @override
  bool operator ==(Object other) {
    return other is ResidentVerificationListFilter &&
        other.status == status &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(status, search);
}

class ResidentVerification {
  const ResidentVerification({
    required this.id,
    required this.userId,
    required this.hoaId,
    this.addressId,
    required this.addressVerified,
    required this.emailVerified,
    required this.activationCodeVerified,
    required this.status,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.residentEmail,
    this.residentName,
    this.residentPhone,
    this.residentStatus,
    this.hoaName,
    this.hoaCode,
    this.addressLine1,
    this.addressLine2,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
  });

  final String id;
  final String userId;
  final String hoaId;
  final String? addressId;
  final bool addressVerified;
  final bool emailVerified;
  final bool activationCodeVerified;
  final ResidentVerificationStatus status;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? residentEmail;
  final String? residentName;
  final String? residentPhone;
  final String? residentStatus;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  String get statusLabel => status.name[0].toUpperCase() + status.name.substring(1);

  String get residentLabel {
    final name = residentName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return residentEmail ?? userId;
  }

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) {
      return '$hoaName ($hoaCode)';
    }
    return hoaName ?? hoaCode ?? hoaId;
  }

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

  bool matchesSearch(String search) {
    final normalized = search.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return [
      residentName,
      residentEmail,
      hoaName,
      hoaCode,
      addressLabel,
    ]
        .whereType<String>()
        .any((value) => value.toLowerCase().contains(normalized));
  }
}

class ResidentApprovalImpact {
  const ResidentApprovalImpact({
    required this.tenantName,
    required this.planName,
    required this.currentResidentCount,
    required this.projectedResidentCount,
    required this.willIncreaseResidentCount,
    this.residentLimit,
  });

  final String tenantName;
  final String planName;
  final int currentResidentCount;
  final int projectedResidentCount;
  final bool willIncreaseResidentCount;
  final int? residentLimit;

  bool get hasResidentLimit => residentLimit != null;
  bool get isAtOrOverIncludedLimit =>
      hasResidentLimit && currentResidentCount >= residentLimit!;
  bool get shouldWarn => willIncreaseResidentCount && isAtOrOverIncludedLimit;

  int get projectedOverageCount {
    if (residentLimit == null || projectedResidentCount <= residentLimit!) return 0;
    return projectedResidentCount - residentLimit!;
  }

  int get projectedMonthlyOverageCents => projectedOverageCount * 5;
}

class ResidentAddressMembershipHistory {
  const ResidentAddressMembershipHistory({
    required this.id,
    required this.userId,
    required this.hoaId,
    required this.addressId,
    required this.occupancyType,
    required this.isPrimary,
    required this.isCurrent,
    required this.startDate,
    this.endDate,
    this.createdBy,
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
  final String userId;
  final String hoaId;
  final String addressId;
  final String occupancyType;
  final bool isPrimary;
  final bool isCurrent;
  final DateTime startDate;
  final DateTime? endDate;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) {
      return '$hoaName ($hoaCode)';
    }
    return hoaName ?? hoaCode ?? hoaId;
  }

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
