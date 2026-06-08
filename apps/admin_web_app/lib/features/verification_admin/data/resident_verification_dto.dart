import '../domain/resident_verification.dart';

class ResidentVerificationDto {
  const ResidentVerificationDto({
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
  final String status;
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

  factory ResidentVerificationDto.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;

    return ResidentVerificationDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      addressId: json['address_id'] as String?,
      addressVerified: json['address_verified'] as bool,
      emailVerified: json['email_verified'] as bool,
      activationCodeVerified: json['activation_code_verified'] as bool,
      status: json['status'] as String,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      residentEmail: profile?['email'] as String?,
      residentName: profile?['full_name'] as String?,
      residentPhone: profile?['phone'] as String?,
      residentStatus: profile?['status'] as String?,
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
      addressLine1: address?['line1'] as String?,
      addressLine2: address?['line2'] as String?,
      addressCity: address?['city'] as String?,
      addressState: address?['state'] as String?,
      addressPostalCode: address?['postal_code'] as String?,
    );
  }

  ResidentVerification toDomain() {
    return ResidentVerification(
      id: id,
      userId: userId,
      hoaId: hoaId,
      addressId: addressId,
      addressVerified: addressVerified,
      emailVerified: emailVerified,
      activationCodeVerified: activationCodeVerified,
      status: ResidentVerificationStatus.fromDatabase(status),
      verifiedAt: verifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      residentEmail: residentEmail,
      residentName: residentName,
      residentPhone: residentPhone,
      residentStatus: residentStatus,
      hoaName: hoaName,
      hoaCode: hoaCode,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      addressCity: addressCity,
      addressState: addressState,
      addressPostalCode: addressPostalCode,
    );
  }
}

class ResidentAddressMembershipHistoryDto {
  const ResidentAddressMembershipHistoryDto({
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

  factory ResidentAddressMembershipHistoryDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;

    return ResidentAddressMembershipHistoryDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      addressId: json['address_id'] as String,
      occupancyType: json['occupancy_type'] as String,
      isPrimary: json['is_primary'] as bool,
      isCurrent: json['is_current'] as bool,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
      addressLine1: address?['line1'] as String?,
      addressLine2: address?['line2'] as String?,
      addressCity: address?['city'] as String?,
      addressState: address?['state'] as String?,
      addressPostalCode: address?['postal_code'] as String?,
    );
  }

  ResidentAddressMembershipHistory toDomain() {
    return ResidentAddressMembershipHistory(
      id: id,
      userId: userId,
      hoaId: hoaId,
      addressId: addressId,
      occupancyType: occupancyType,
      isPrimary: isPrimary,
      isCurrent: isCurrent,
      startDate: startDate,
      endDate: endDate,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      addressCity: addressCity,
      addressState: addressState,
      addressPostalCode: addressPostalCode,
    );
  }
}
