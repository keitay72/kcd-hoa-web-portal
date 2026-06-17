import '../domain/resident_address.dart';

class VerifiedResidentAddressDto {
  const VerifiedResidentAddressDto({
    required this.id,
    required this.hoaId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    this.hoaName,
    this.hoaCode,
    this.tenantName,
    this.tenantCode,
  });

  final String id;
  final String hoaId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String? hoaName;
  final String? hoaCode;
  final String? tenantName;
  final String? tenantCode;

  factory VerifiedResidentAddressDto.fromJson(Map<String, dynamic> json) {
    return VerifiedResidentAddressDto(
      id: json['id'] as String,
      hoaId: json['hoaId'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      hoaName: json['hoaName'] as String?,
      hoaCode: json['hoaCode'] as String?,
      tenantName: json['tenantName'] as String?,
      tenantCode: json['tenantCode'] as String?,
    );
  }

  VerifiedResidentAddress toDomain() {
    return VerifiedResidentAddress(
      id: id,
      hoaId: hoaId,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      hoaName: hoaName,
      hoaCode: hoaCode,
      tenantName: tenantName,
      tenantCode: tenantCode,
    );
  }
}
