class HoaResident {
  const HoaResident({
    required this.userId,
    required this.hoaId,
    required this.addressId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.profileStatus,
    required this.occupancyType,
    required this.isPrimary,
    required this.startDate,
    required this.addressLabel,
  });

  final String userId;
  final String hoaId;
  final String addressId;
  final String fullName;
  final String email;
  final String? phone;
  final String profileStatus;
  final String occupancyType;
  final bool isPrimary;
  final DateTime startDate;
  final String addressLabel;

  String get displayName => fullName.trim().isEmpty ? email : fullName;
  String get occupancyLabel => _label(occupancyType);
  String get statusLabel => _label(profileStatus);
}

String _label(String value) {
  if (value.isEmpty) return value;
  final spaced = value.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
