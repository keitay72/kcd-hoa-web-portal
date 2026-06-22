String customerPortalDisplayName(String? tenantCode) {
  final code = tenantCode?.trim();
  if (code == null || code.isEmpty) return 'Customer Portal';

  return code
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.trim().isNotEmpty)
      .map(_titleCaseTenantPart)
      .join(' ');
}

String customerPortalTitle(String? tenantCode) {
  final displayName = customerPortalDisplayName(tenantCode);
  return displayName == 'Customer Portal'
      ? displayName
      : '$displayName Customer Portal';
}

String _titleCaseTenantPart(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return normalized;
  if (normalized.length <= 2) return normalized.toUpperCase();
  return normalized[0].toUpperCase() + normalized.substring(1);
}
