class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
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
  final List<UserPlatformRoleAssignment> platformRoles;
  final List<UserHoaRoleAssignment> hoaRoles;
  final AdminUserInvite? latestInvite;

  String get displayName => fullName == null || fullName!.trim().isEmpty ? email : fullName!;
  bool get isActive => status == 'active';
  bool get isPendingInvite => status == 'invite_pending' || latestInvite?.status == 'pending';
  bool get isFailedInvite => latestInvite?.status == 'failed';
  bool get canResendInvite => latestInvite?.canResend == true;
  bool get canCancelInvite => latestInvite?.canCancel == true;
  bool get hasPlatformRoles => platformRoles.isNotEmpty;
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
      ...platformRoles.map((role) => role.roleName),
      ...hoaRoles.map((role) => '${role.roleName} - ${role.hoaName}'),
    ]..sort();
    return labels.isEmpty ? 'No roles assigned' : labels.join(', ');
  }
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
