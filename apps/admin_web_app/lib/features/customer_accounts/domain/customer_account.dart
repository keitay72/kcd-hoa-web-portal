enum CustomerAccountType {
  residential,
  community,
  commercial,
  rollOff;

  static CustomerAccountType fromDatabase(String value) {
    return switch (value) {
      'roll_off' => CustomerAccountType.rollOff,
      _ => CustomerAccountType.values.firstWhere(
          (type) => type.name == value,
          orElse: () => CustomerAccountType.residential,
        ),
    };
  }

  String get databaseValue {
    return switch (this) {
      CustomerAccountType.rollOff => 'roll_off',
      _ => name,
    };
  }

  String get label {
    return switch (this) {
      CustomerAccountType.residential => 'Residential',
      CustomerAccountType.community => 'Community',
      CustomerAccountType.commercial => 'Commercial',
      CustomerAccountType.rollOff => 'Roll off',
    };
  }
}

enum CustomerAccountStatus {
  active,
  inactive,
  suspended;

  static CustomerAccountStatus fromDatabase(String value) {
    return CustomerAccountStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CustomerAccountStatus.inactive,
    );
  }

  String get label {
    return switch (this) {
      CustomerAccountStatus.active => 'Active',
      CustomerAccountStatus.inactive => 'Inactive',
      CustomerAccountStatus.suspended => 'Suspended',
    };
  }
}

class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.tenantId,
    required this.accountType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.accountNumber,
    this.name,
    this.externalAccountRef,
    this.metadata = const {},
    this.serviceLocationCount,
  });

  final String id;
  final String tenantId;
  final String? accountNumber;
  final CustomerAccountType accountType;
  final String? name;
  final CustomerAccountStatus status;
  final String? externalAccountRef;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? serviceLocationCount;

  bool get isActive => status == CustomerAccountStatus.active;

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final trimmedAccountNumber = accountNumber?.trim();
    if (trimmedAccountNumber != null && trimmedAccountNumber.isNotEmpty) {
      return 'Account $trimmedAccountNumber';
    }

    return accountType.label;
  }
}
