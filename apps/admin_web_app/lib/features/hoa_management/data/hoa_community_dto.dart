import '../domain/hoa_community.dart';

class HoaCommunityDto {
  const HoaCommunityDto({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.residentActivationCodesRequiredOverride,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? residentActivationCodesRequiredOverride;

  factory HoaCommunityDto.fromJson(Map<String, dynamic> json) {
    return HoaCommunityDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      residentActivationCodesRequiredOverride:
          json['resident_activation_codes_required_override'] as bool?,
    );
  }

  HoaCommunity toDomain() {
    return HoaCommunity(
      id: id,
      tenantId: tenantId,
      code: code,
      name: name,
      status: HoaCommunityStatus.fromDatabase(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      residentActivationCodesRequiredOverride:
          residentActivationCodesRequiredOverride,
    );
  }
}
