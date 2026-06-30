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
    required this.communityType,
    this.city,
    this.state,
    this.residentActivationCodesRequiredOverride,
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? communityType;
  final String? city;
  final String? state;
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
      communityType: json['community_type'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
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
      communityType: CommunityType.fromDatabase(communityType),
      city: city,
      state: state,
      residentActivationCodesRequiredOverride:
          residentActivationCodesRequiredOverride,
    );
  }
}
