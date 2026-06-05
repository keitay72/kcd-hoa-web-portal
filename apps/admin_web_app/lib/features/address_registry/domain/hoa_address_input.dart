import 'address_normalizer.dart';

class HoaAddressInput {
  const HoaAddressInput({
    required this.hoaId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.isActive,
  });

  final String hoaId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final bool isActive;

  String get normalizedKey => AddressNormalizer.normalizedKey(
        line1: line1,
        line2: line2,
        city: city,
        state: state,
        postalCode: postalCode,
      );

  Map<String, dynamic> toJson() {
    final trimmedLine2 = line2?.trim();

    return {
      'hoa_id': hoaId,
      'line1': line1.trim(),
      'line2': trimmedLine2 == null || trimmedLine2.isEmpty ? null : trimmedLine2,
      'city': city.trim(),
      'state': AddressNormalizer.normalizeState(state),
      'postal_code': AddressNormalizer.normalizePostalCode(postalCode),
      'normalized_key': normalizedKey,
      'is_active': isActive,
    };
  }
}
