import 'hoa_community.dart';

class HoaCodeGenerator {
  const HoaCodeGenerator._();

  static String baseCodeFromName(
    String name, {
    CommunityType communityType = CommunityType.hoa,
  }) {
    var normalized = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (normalized == 'HOA') {
      normalized = '';
    }

    if (normalized.endsWith('_HOA')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }

    normalized = normalized.replaceAll(RegExp(r'^_|_$'), '');

    if (normalized.isEmpty) {
      return communityType == CommunityType.city
          ? 'CITY_SERVICE'
          : 'HOA_COMMUNITY';
    }

    if (communityType == CommunityType.city) {
      return normalized.startsWith('CITY_') ? normalized : 'CITY_$normalized';
    }

    return normalized.startsWith('HOA_') ? normalized : 'HOA_$normalized';
  }

  static String uniqueCodeForName({
    required String name,
    required Iterable<String> existingCodes,
    CommunityType communityType = CommunityType.hoa,
  }) {
    final baseCode = baseCodeFromName(name, communityType: communityType);
    final existing = existingCodes.toSet();

    if (!existing.contains(baseCode)) {
      return baseCode;
    }

    var suffix = 2;
    while (existing.contains('${baseCode}_$suffix')) {
      suffix += 1;
    }

    return '${baseCode}_$suffix';
  }
}
