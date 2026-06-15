class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorUserId,
    this.actorName,
    this.actorEmail,
    this.tenantId,
    this.tenantName,
    this.tenantCode,
    this.hoaId,
    this.hoaName,
    this.hoaCode,
    this.beforeJson,
    this.afterJson,
    this.ip,
    this.userAgent,
  });

  final String id;
  final String? actorUserId;
  final String? actorName;
  final String? actorEmail;
  final String? tenantId;
  final String? tenantName;
  final String? tenantCode;
  final String? hoaId;
  final String? hoaName;
  final String? hoaCode;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;
  final String? ip;
  final String? userAgent;
  final DateTime createdAt;

  String get actorLabel {
    if (actorName != null && actorName!.trim().isNotEmpty) return actorName!;
    if (actorEmail != null && actorEmail!.trim().isNotEmpty) return actorEmail!;
    if (actorUserId != null && actorUserId!.trim().isNotEmpty) return actorUserId!;
    return 'System';
  }

  String get hoaLabel {
    if (hoaName != null && hoaName!.trim().isNotEmpty) {
      if (hoaCode != null && hoaCode!.trim().isNotEmpty) return '$hoaName ($hoaCode)';
      return hoaName!;
    }
    if (tenantName != null && tenantName!.trim().isNotEmpty) {
      if (tenantCode != null && tenantCode!.trim().isNotEmpty) return '$tenantName ($tenantCode)';
      return tenantName!;
    }
    return tenantId ?? 'Platform';
  }

  String get entityLabel => '$entityType · $entityId';
}

class AuditLogFilters {
  const AuditLogFilters({
    this.search,
    this.action,
    this.entityType,
    this.hoaId,
    this.limit = 200,
  });

  final String? search;
  final String? action;
  final String? entityType;
  final String? hoaId;
  final int limit;

  bool get hasFilters {
    return (search?.trim().isNotEmpty ?? false) ||
        (action?.trim().isNotEmpty ?? false) ||
        (entityType?.trim().isNotEmpty ?? false) ||
        (hoaId?.trim().isNotEmpty ?? false);
  }

  AuditLogFilters copyWith({
    String? search,
    String? action,
    String? entityType,
    String? hoaId,
    int? limit,
    bool clearSearch = false,
    bool clearAction = false,
    bool clearEntityType = false,
    bool clearHoa = false,
  }) {
    return AuditLogFilters(
      search: clearSearch ? null : search ?? this.search,
      action: clearAction ? null : action ?? this.action,
      entityType: clearEntityType ? null : entityType ?? this.entityType,
      hoaId: clearHoa ? null : hoaId ?? this.hoaId,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuditLogFilters &&
        other.search == search &&
        other.action == action &&
        other.entityType == entityType &&
        other.hoaId == hoaId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(search, action, entityType, hoaId, limit);
}

class AuditHoaOption {
  const AuditHoaOption({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  String get label => code.trim().isEmpty ? name : '$name ($code)';
}
