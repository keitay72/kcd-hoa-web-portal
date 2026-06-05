import '../domain/activation_code_address_option.dart';

class ActivationCodeAddressOptionDto {
  const ActivationCodeAddressOptionDto({
    required this.id,
    required this.hoaId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.isActive,
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
  final bool isActive;
  final String? hoaName;
  final String? hoaCode;

  factory ActivationCodeAddressOptionDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;

    return ActivationCodeAddressOptionDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postal_code'] as String,
      isActive: json['is_active'] as bool,
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
    );
  }

  ActivationCodeAddressOption toDomain() {
    return ActivationCodeAddressOption(
      id: id,
      hoaId: hoaId,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      isActive: isActive,
      hoaName: hoaName,
      hoaCode: hoaCode,
    );
  }
}
