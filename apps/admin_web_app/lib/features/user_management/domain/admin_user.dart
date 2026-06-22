class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.globalRoles,
    required this.platformRoles,
    required this.hoaRoles,
    this.latestInvite,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UserGlobalRoleAssignment> globalRoles;
  final List<UserPlatformRoleAssignment> platformRoles;
  final List<UserHoaRoleAssignment> hoaRoles;
  final AdminUserInvite? latestInvite;

  String get displayName =>
      fullName == null || fullName!.trim().isEmpty ? email : fullName!;
  bool get isActive => status == 'active';
  bool get isPendingInvite =>
      status == 'invite_pending' || latestInvite?.status == 'pending';
  bool get isFailedInvite => latestInvite?.status == 'failed';
  bool get canResendInvite => latestInvite?.canResend == true;
  bool get canCancelInvite => latestInvite?.canCancel == true;
  bool get hasGlobalRoles => globalRoles.isNotEmpty;
  bool get hasPlatformRoles =>
      globalRoles.isNotEmpty || platformRoles.isNotEmpty;
  bool get isPlatformOwner =>
      globalRoles.any((role) => role.roleCode == 'platform_owner');
  bool get isPlatformAdmin =>
      globalRoles.any((role) => role.roleCode == 'platform_admin');
  bool get hasHoaRoles => hoaRoles.isNotEmpty;

  String get statusLabel {
    return switch (status) {
      'active' => 'Active',
      'disabled' => 'Disabled',
      'invite_pending' => 'Pending Invite',
      'invite_expired' => 'Invite Expired',
      'invite_failed' => 'Invite Failed',
      'invite_cancelled' => 'Invite Cancelled',
      'invite_accepted' => 'Invite Accepted',
      _ => status,
    };
  }

  String get roleSummary {
    final labels = <String>[
      ...globalRoles.map((role) => role.roleName),
      ...platformRoles.map((role) => role.roleName),
      ...hoaRoles.map((role) => '${role.roleName} - ${role.hoaName}'),
    ]..sort();
    return labels.isEmpty ? 'No roles assigned' : labels.join(', ');
  }
}

class UserGlobalRoleAssignment {
  const UserGlobalRoleAssignment({
    required this.userId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.createdAt,
  });

  final String userId;
  final int roleId;
  final String roleCode;
  final String roleName;
  final DateTime createdAt;
}

class AdminUserInvite {
  const AdminUserInvite({
    required this.id,
    required this.userId,
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

  bool get canResend => const {'pending', 'expired', 'failed'}.contains(status);
  bool get canCancel => const {'pending', 'expired', 'failed'}.contains(status);

  String get statusLabel {
    return switch (status) {
      'pending' => 'Pending Invite',
      'accepted' => 'Accepted',
      'expired' => 'Expired',
      'cancelled' => 'Cancelled',
      'failed' => 'Failed',
      _ => status,
    };
  }
}

class UserPlatformRoleAssignment {
  const UserPlatformRoleAssignment({
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
}

class UserHoaRoleAssignment {
  const UserHoaRoleAssignment({
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
}

class UserAccountActivity {
  const UserAccountActivity({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    required this.actorLabel,
    this.beforeJson,
    this.afterJson,
  });

  final String id;
  final String action;
  final String entityType;
  final DateTime createdAt;
  final String actorLabel;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;

  String get actionLabel {
    return switch (action) {
      'user.profile_updated' => 'Profile updated',
      'user.deactivated' => 'Deactivated',
      'user.reactivated' => 'Reactivated',
      'user.password_updated' => 'Password changed',
      'role.tenant_assigned' => 'Tenant role assigned',
      'role.tenant_removed' => 'Tenant role removed',
      'role.hoa_assigned' => 'Community role assigned',
      'role.hoa_removed' => 'Community role removed',
      _ => action,
    };
  }

  String? get statusChange {
    final beforeStatus = beforeJson?['status']?.toString();
    final afterStatus = afterJson?['status']?.toString();
    if (beforeStatus == null || afterStatus == null) return null;
    if (beforeStatus == afterStatus) return null;
    return '${_statusLabel(beforeStatus)} -> ${_statusLabel(afterStatus)}';
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'active' => 'Active',
      'disabled' => 'Disabled',
      'inactive' => 'Inactive',
      _ => status,
    };
  }
}
