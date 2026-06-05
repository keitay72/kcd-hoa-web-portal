import 'hoa_community.dart';

class HoaCommunityInput {
  const HoaCommunityInput({
    required this.name,
    required this.status,
  });

  final String name;
  final HoaCommunityStatus status;

  Map<String, dynamic> toInsertJson({
    required String tenantId,
    required String code,
  }) {
    return {
      'tenant_id': tenantId,
      'code': code,
      'name': name,
      'status': status.name,
    };
  }

  Map<String, dynamic> toUpdateJson({required String code}) {
    return {
      'code': code,
      'name': name,
      'status': status.name,
    };
  }
}
