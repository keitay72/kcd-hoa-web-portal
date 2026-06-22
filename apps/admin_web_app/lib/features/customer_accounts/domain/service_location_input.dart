import '../../address_registry/domain/address_normalizer.dart';
import 'service_location.dart';

class ServiceLocationInput {
  const ServiceLocationInput({
    required this.customerAccountId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.status,
    this.externalLocationRef,
    this.metadata = const {},
  });

  final String customerAccountId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final ServiceLocationStatus status;
  final String? externalLocationRef;
  final Map<String, dynamic> metadata;

  String get normalizedKey => AddressNormalizer.normalizedKey(
        line1: line1,
        line2: line2,
        city: city,
        state: state,
        postalCode: postalCode,
      );

  Map<String, dynamic> toInsertJson({required String tenantId}) {
    return {
      'tenant_id': tenantId,
      ...toUpdateJson(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final trimmedLine2 = line2?.trim();

    return {
      'customer_account_id': customerAccountId,
      'line1': line1.trim(),
      'line2':
          trimmedLine2 == null || trimmedLine2.isEmpty ? null : trimmedLine2,
      'city': city.trim(),
      'state': AddressNormalizer.normalizeState(state),
      'postal_code': AddressNormalizer.normalizePostalCode(postalCode),
      'normalized_key': normalizedKey,
      'status': status.name,
      'external_location_ref': _blankToNull(externalLocationRef),
      'metadata': metadata,
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
