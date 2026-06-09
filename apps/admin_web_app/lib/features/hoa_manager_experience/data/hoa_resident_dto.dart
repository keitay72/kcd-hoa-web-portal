import '../domain/hoa_resident.dart';

class HoaResidentDto {
  const HoaResidentDto({
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

  factory HoaResidentDto.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;
    final addressParts = <String?>[
      address?['line1'] as String?,
      address?['line2'] as String?,
      address?['city'] as String?,
      address?['state'] as String?,
      address?['postal_code'] as String?,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

    return HoaResidentDto(
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      addressId: json['address_id'] as String,
      fullName: profile?['full_name'] as String? ?? '',
      email: profile?['email'] as String? ?? 'No email',
      phone: profile?['phone'] as String?,
      profileStatus: profile?['status'] as String? ?? 'active',
      occupancyType: json['occupancy_type'] as String? ?? 'resident',
      isPrimary: json['is_primary'] as bool? ?? false,
      startDate: DateTime.parse(json['start_date'] as String),
      addressLabel: addressParts.isEmpty ? json['address_id'] as String : addressParts.join(', '),
    );
  }

  HoaResident toDomain() {
    return HoaResident(
      userId: userId,
      hoaId: hoaId,
      addressId: addressId,
      fullName: fullName,
      email: email,
      phone: phone,
      profileStatus: profileStatus,
      occupancyType: occupancyType,
      isPrimary: isPrimary,
      startDate: startDate,
      addressLabel: addressLabel,
    );
  }
}
