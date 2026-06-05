import '../domain/hoa_address.dart';

class HoaAddressDto {
  const HoaAddressDto({
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

  factory HoaAddressDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;

    return HoaAddressDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postal_code'] as String,
      normalizedKey: json['normalized_key'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
    );
  }

  HoaAddress toDomain() {
    return HoaAddress(
      id: id,
      hoaId: hoaId,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      normalizedKey: normalizedKey,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
    );
  }
}
