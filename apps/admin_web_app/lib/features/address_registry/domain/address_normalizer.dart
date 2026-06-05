class AddressNormalizer {
  const AddressNormalizer._();

  static String normalizedKey({
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String postalCode,
  }) {
    return <String?>[
      line1,
      line2,
      city,
      normalizeState(state),
      normalizePostalCode(postalCode),
    ]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .map(_normalizePart)
        .join('|');
  }

  static String normalizeState(String value) {
    return value.trim().toUpperCase();
  }

  static String normalizePostalCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String _normalizePart(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
