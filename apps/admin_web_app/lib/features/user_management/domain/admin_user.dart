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

  String get displayName => fullName == null || fullName!.trim().isEmpty ? email : fullName!;
  bool get isActive => status == 'active';
  bool get hasPlatformRoles => platformRoles.isNotEmpty;
  bool get hasHoaRoles => hoaRoles.isNotEmpty;

  String get roleSummary {
    final labels = <String>[
      ...platformRoles.map((role) => role.roleName),
      ...hoaRoles.map((role) => '${role.roleName} - ${role.hoaName}'),
    ]..sort();
    return labels.isEmpty ? 'No roles assigned' : labels.join(', ');
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
