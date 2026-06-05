import '../domain/activation_code.dart';

class ActivationCodeDto {
  const ActivationCodeDto({
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
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  factory ActivationCodeDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;

    return ActivationCodeDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      addressId: json['address_id'] as String,
      codeHash: json['code_hash'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      consumedAt: json['consumed_at'] == null
          ? null
          : DateTime.parse(json['consumed_at'] as String),
      consumedBy: json['consumed_by'] as String?,
      resetCount: json['reset_count'] as int,
      status: json['status'] as String,
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

  ActivationCode toDomain() {
    return ActivationCode(
      id: id,
      hoaId: hoaId,
      addressId: addressId,
      codeHash: codeHash,
      expiresAt: expiresAt,
      consumedAt: consumedAt,
      consumedBy: consumedBy,
      resetCount: resetCount,
      status: ActivationCodeStatus.fromDatabase(status),
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
