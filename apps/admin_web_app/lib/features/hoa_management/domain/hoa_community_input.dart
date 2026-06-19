import 'hoa_community.dart';

class HoaCommunityInput {
  const HoaCommunityInput({
    required this.name,
    required this.status,
    this.residentActivationCodesRequiredOverride,
  });

  final String name;
  final HoaCommunityStatus status;
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
      'resident_activation_codes_required_override':
          residentActivationCodesRequiredOverride,
    };
  }

  Map<String, dynamic> toUpdateJson({required String code}) {
    return {
      'code': code,
      'name': name,
      'status': status.name,
      'resident_activation_codes_required_override':
          residentActivationCodesRequiredOverride,
    };
  }
}
