class ServiceLocation {
  const ServiceLocation({
    required this.id,
    required this.tenantId,
    required this.customerAccountId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.normalizedKey,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.externalLocationRef,
    this.metadata = const {},
    this.customerAccountName,
    this.customerAccountNumber,
  });

  final String id;
  final String tenantId;
  final String customerAccountId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String normalizedKey;
  final ServiceLocationStatus status;
  final String? externalLocationRef;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerAccountName;
  final String? customerAccountNumber;

  bool get isActive => status == ServiceLocationStatus.active;

  String get statusLabel => status.label;

  String get singleLine {
    return <String?>[line1, line2, city, state, postalCode]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}

enum ServiceLocationStatus {
  active,
  inactive;

  static ServiceLocationStatus fromDatabase(String value) {
    return ServiceLocationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ServiceLocationStatus.inactive,
    );
  }

  String get label {
    return switch (this) {
      ServiceLocationStatus.active => 'Active',
      ServiceLocationStatus.inactive => 'Inactive',
    };
  }
}
