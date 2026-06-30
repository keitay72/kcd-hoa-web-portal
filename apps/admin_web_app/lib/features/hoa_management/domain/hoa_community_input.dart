import 'hoa_community.dart';

class HoaCommunityInput {
  const HoaCommunityInput({
    required this.name,
    required this.status,
    this.communityType = CommunityType.hoa,
    this.city,
    this.state,
    this.residentActivationCodesRequiredOverride,
  });

  final String name;
  final HoaCommunityStatus status;
  final CommunityType communityType;
  final String? city;
  final String? state;
  final bool? residentActivationCodesRequiredOverride;

  Map<String, dynamic> toInsertJson({
    required String tenantId,
    required String code,
  }) {
    return {
      'tenant_id': tenantId,
      'code': code,
      'name': name,
      'status': status.name,
      'community_type': communityType.name,
      'city': city,
      'state': state,
      'resident_activation_codes_required_override':
          residentActivationCodesRequiredOverride,
    };
  }

  Map<String, dynamic> toUpdateJson({required String code}) {
    return {
      'code': code,
      'name': name,
      'status': status.name,
      'community_type': communityType.name,
      'city': city,
      'state': state,
      'resident_activation_codes_required_override':
          residentActivationCodesRequiredOverride,
    };
  }
}
