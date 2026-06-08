class HoaAddress {
  const HoaAddress({
    required this.id,
    required this.hoaId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.normalizedKey,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
    this.activationCodeId,
    this.activationCodeStatus,
    this.activationCodeExpiresAt,
    this.activationCodeConsumedAt,
    this.activationCodeResetCount,
  });

  final String id;
  final String hoaId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String normalizedKey;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? activationCodeId;
  final String? activationCodeStatus;
  final DateTime? activationCodeExpiresAt;
  final DateTime? activationCodeConsumedAt;
  final int? activationCodeResetCount;

  String get statusLabel => isActive ? 'Active' : 'Inactive';

  bool get hasActivationCode => activationCodeId != null;

  String get activationCodeStatusLabel {
    final status = activationCodeStatus;
    if (status == null) {
      return 'None';
    }

    if (status == 'active' &&
        activationCodeExpiresAt != null &&
        activationCodeExpiresAt!.isBefore(DateTime.now().toUtc())) {
      return 'Expired';
    }

    return status[0].toUpperCase() + status.substring(1);
  }

  String get singleLine {
    return <String?>[line1, line2, city, state, postalCode]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}
