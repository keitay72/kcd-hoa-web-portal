import '../domain/audit_log.dart';

class AuditLogEntryDto {
  const AuditLogEntryDto({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorUserId,
    this.tenantId,
    this.hoaId,
    this.beforeJson,
    this.afterJson,
    this.ip,
    this.userAgent,
  });

  final String id;
  final String? actorUserId;
  final String? tenantId;
  final String? hoaId;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;
  final String? ip;
  final String? userAgent;
  final DateTime createdAt;

  factory AuditLogEntryDto.fromJson(Map<String, dynamic> json) {
    return AuditLogEntryDto(
      id: json['id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      tenantId: json['tenant_id'] as String?,
      hoaId: json['hoa_id'] as String?,
      action: json['action'] as String? ?? 'unknown',
      entityType: json['entity_type'] as String? ?? 'unknown',
      entityId: json['entity_id'] as String? ?? 'unknown',
      beforeJson: _jsonMap(json['before_json']),
      afterJson: _jsonMap(json['after_json']),
      ip: json['ip'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AuditLogEntry toDomain({
    String? actorName,
    String? actorEmail,
    String? tenantName,
    String? tenantCode,
    String? hoaName,
    String? hoaCode,
  }) {
    return AuditLogEntry(
      id: id,
      actorUserId: actorUserId,
      actorName: actorName,
      actorEmail: actorEmail,
      tenantId: tenantId,
      tenantName: tenantName,
      tenantCode: tenantCode,
      hoaId: hoaId,
      hoaName: hoaName,
      hoaCode: hoaCode,
      action: action,
      entityType: entityType,
      entityId: entityId,
      beforeJson: beforeJson,
      afterJson: afterJson,
      ip: ip,
      userAgent: userAgent,
      createdAt: createdAt,
    );
  }

  static Map<String, dynamic>? _jsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

class AuditHoaOptionDto {
  const AuditHoaOptionDto({
    required this.id,
    required this.name,
    required this.code,
  });

  final String id;
  final String name;
  final String code;

  factory AuditHoaOptionDto.fromJson(Map<String, dynamic> json) {
    return AuditHoaOptionDto(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed HOA',
      code: json['code'] as String? ?? '',
    );
  }

  AuditHoaOption toDomain() {
    return AuditHoaOption(id: id, name: name, code: code);
  }
}
