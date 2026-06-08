enum ServiceScheduleType {
  trash,
  recycling,
  yardWaste,
  bulk;

  static ServiceScheduleType fromDatabase(String value) {
    return ServiceScheduleType.values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => ServiceScheduleType.trash,
    );
  }

  String get databaseValue {
    return switch (this) {
      ServiceScheduleType.trash => 'trash',
      ServiceScheduleType.recycling => 'recycling',
      ServiceScheduleType.yardWaste => 'yard_waste',
      ServiceScheduleType.bulk => 'bulk',
    };
  }

  String get label {
    return switch (this) {
      ServiceScheduleType.trash => 'Trash',
      ServiceScheduleType.recycling => 'Recycling',
      ServiceScheduleType.yardWaste => 'Yard Waste',
      ServiceScheduleType.bulk => 'Bulk Pickup',
    };
  }
}

enum ServiceScheduleStatus {
  active,
  archived;

  static ServiceScheduleStatus fromDatabase(String value) {
    return ServiceScheduleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ServiceScheduleStatus.active,
    );
  }

  String get label => name[0].toUpperCase() + name.substring(1);
}

class ServiceSchedule {
  const ServiceSchedule({
    required this.id,
    required this.hoaId,
    this.addressId,
    required this.serviceType,
    required this.scheduleRule,
    this.routeName,
    required this.effectiveDate,
    this.endDate,
    required this.status,
    this.notes,
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
  final String? addressId;
  final ServiceScheduleType serviceType;
  final String scheduleRule;
  final String? routeName;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final ServiceScheduleStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  bool get isArchived => status == ServiceScheduleStatus.archived;
  bool get isOverride => addressId != null;
  bool get isHoaWide => addressId == null;

  String get statusLabel => status.label;
  String get serviceTypeLabel => serviceType.label;
  String get routeNameLabel => routeName == null || routeName!.trim().isEmpty
      ? 'Not set'
      : routeName!.trim();
  String get scheduleScopeLabel => isOverride ? 'Address Override' : 'HOA Default';

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) {
      return '$hoaName ($hoaCode)';
    }
    return hoaName ?? hoaCode ?? hoaId;
  }

  String get addressLabel {
    if (addressId == null) {
      return 'HOA-wide default';
    }

    final parts = <String?>[
      addressLine1,
      addressLine2,
      addressCity,
      addressState,
      addressPostalCode,
    ]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList();

    return parts.isEmpty ? addressId! : parts.join(', ');
  }
}
