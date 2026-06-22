class ResidentAddressInput {
  const ResidentAddressInput({
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;

  Map<String, dynamic> toJson() {
    return {
      'line1': line1.trim(),
      'line2': line2?.trim(),
      'city': city.trim(),
      'state': state.trim().toUpperCase(),
      'postalCode': postalCode.trim(),
    };
  }

  String get singleLine {
    return <String?>[line1, line2, city, state, postalCode]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}

class VerifiedResidentAddress {
  const VerifiedResidentAddress({
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

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) return '$hoaName ($hoaCode)';
    return hoaName ?? hoaCode ?? hoaId;
  }

  String get portalLabel {
    if (tenantName != null && tenantName!.trim().isNotEmpty) {
      return '$tenantName Customer Portal';
    }
    if (tenantCode != null && tenantCode!.trim().isNotEmpty) {
      return '$tenantCode Customer Portal';
    }
    return 'Customer Portal';
  }

  String get singleLine {
    return <String?>[line1, line2, city, state, postalCode]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}
