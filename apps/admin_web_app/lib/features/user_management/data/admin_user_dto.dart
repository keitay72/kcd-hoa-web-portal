import '../domain/admin_user.dart';

class AdminUserDto {
  const AdminUserDto({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminUserDto.fromJson(Map<String, dynamic> json) {
    return AdminUserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  AdminUser toDomain({
    required List<UserPlatformRoleAssignment> platformRoles,
    required List<UserHoaRoleAssignment> hoaRoles,
    AdminUserInvite? latestInvite,
  }) {
    return AdminUser(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      platformRoles: platformRoles,
      hoaRoles: hoaRoles,
      latestInvite: latestInvite,
    );
  }
}

class AdminUserInviteDto {
  const AdminUserInviteDto({
    required this.id,
    this.userId,
    required this.email,
    required this.roleCode,
    required this.status,
    required this.invitedAt,
    required this.expiresAt,
    this.acceptedAt,
    this.resentAt,
    required this.resendCount,
    this.cancelledAt,
    this.failureMessage,
    this.failureReason,
    this.failureTimestamp,
  });

  final String id;
  final String? userId;
  final String email;
  final String roleCode;
  final String status;
  final DateTime invitedAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? resentAt;
  final int resendCount;
  final DateTime? cancelledAt;
  final String? failureMessage;
  final String? failureReason;
  final DateTime? failureTimestamp;

  factory AdminUserInviteDto.fromJson(Map<String, dynamic> json) {
    return AdminUserInviteDto(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String,
      roleCode: json['role_code'] as String,
      status: json['status'] as String? ?? 'pending',
      invitedAt: DateTime.parse(json['invited_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: _optionalDate(json['accepted_at']),
      resentAt: _optionalDate(json['resent_at']),
      resendCount: json['resend_count'] as int? ?? 0,
      cancelledAt: _optionalDate(json['cancelled_at']),
      failureMessage: json['failure_message'] as String?,
      failureReason: json['failure_reason'] as String?,
      failureTimestamp: _optionalDate(json['failure_timestamp']),
    );
  }

  AdminUserInvite toDomain() {
    return AdminUserInvite(
      id: id,
      userId: userId,
      email: email,
      roleCode: roleCode,
      status: status,
      invitedAt: invitedAt,
      expiresAt: expiresAt,
      acceptedAt: acceptedAt,
      resentAt: resentAt,
      resendCount: resendCount,
      cancelledAt: cancelledAt,
      failureMessage: failureMessage,
      failureReason: failureReason,
      failureTimestamp: failureTimestamp,
    );
  }
}

DateTime? _optionalDate(Object? value) {
  return value is String ? DateTime.parse(value) : null;
}

class UserPlatformRoleAssignmentDto {
  const UserPlatformRoleAssignmentDto({
    required this.userId,
    required this.tenantId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.tenantName,
    required this.createdAt,
  });

  final String userId;
  final String tenantId;
  final int roleId;
  final String roleCode;
  final String roleName;
  final String tenantName;
  final DateTime createdAt;

  factory UserPlatformRoleAssignmentDto.fromJson(Map<String, dynamic> json) {
    final role = json['roles'] as Map<String, dynamic>?;
    final tenant = json['platform_tenants'] as Map<String, dynamic>?;
    return UserPlatformRoleAssignmentDto(
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      roleId: json['role_id'] as int,
      roleCode: role?['code'] as String? ?? 'unknown',
      roleName: role?['name'] as String? ?? 'Unknown role',
      tenantName: tenant?['name'] as String? ?? 'Tenant',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  UserPlatformRoleAssignment toDomain() {
    return UserPlatformRoleAssignment(
      userId: userId,
      tenantId: tenantId,
      roleId: roleId,
      roleCode: roleCode,
      roleName: roleName,
      tenantName: tenantName,
      createdAt: createdAt,
    );
  }
}

class UserHoaRoleAssignmentDto {
  const UserHoaRoleAssignmentDto({
    required this.userId,
    required this.hoaId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.hoaName,
    required this.status,
    required this.createdAt,
  });

  final String userId;
  final String hoaId;
  final int roleId;
  final String roleCode;
  final String roleName;
  final String hoaName;
  final String status;
  final DateTime createdAt;

  factory UserHoaRoleAssignmentDto.fromJson(Map<String, dynamic> json) {
    final role = json['roles'] as Map<String, dynamic>?;
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    return UserHoaRoleAssignmentDto(
      userId: json['user_id'] as String,
      hoaId: json['hoa_id'] as String,
      roleId: json['role_id'] as int,
      roleCode: role?['code'] as String? ?? 'unknown',
      roleName: role?['name'] as String? ?? 'Unknown role',
      hoaName: hoa?['name'] as String? ?? 'HOA',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  UserHoaRoleAssignment toDomain() {
    return UserHoaRoleAssignment(
      userId: userId,
      hoaId: hoaId,
      roleId: roleId,
      roleCode: roleCode,
      roleName: roleName,
      hoaName: hoaName,
      status: status,
      createdAt: createdAt,
    );
  }
}
