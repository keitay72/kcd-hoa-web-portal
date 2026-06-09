class InviteAdminUserInput {
  const InviteAdminUserInput({
    required this.email,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.phone,
    required this.roleCode,
    this.tenantId,
    this.hoaId,
  });

  final String email;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? phone;
  final String roleCode;
  final String? tenantId;
  final String? hoaId;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'first_name': firstName.trim(),
      'middle_name': _emptyToNull(middleName),
      'last_name': lastName.trim(),
      'phone': _digitsOnly(phone),
      'role': roleCode,
      'tenant_id': tenantId,
      'hoa_id': hoaId,
    };
  }
}


class InviteLifecycleActionInput {
  const InviteLifecycleActionInput({
    required this.action,
    required this.inviteId,
  });

  final String action;
  final String inviteId;

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'invite_id': inviteId,
    };
  }
}

class UpdateAdminUserInput {
  const UpdateAdminUserInput({
    required this.fullName,
    this.phone,
    required this.status,
  });

  final String fullName;
  final String? phone;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName.trim(),
      'phone': _digitsOnly(phone),
      'status': status,
    };
  }
}

class AssignPlatformRoleInput {
  const AssignPlatformRoleInput({
    required this.userId,
    required this.tenantId,
    required this.roleId,
  });

  final String userId;
  final String tenantId;
  final int roleId;
}

class AssignHoaRoleInput {
  const AssignHoaRoleInput({
    required this.userId,
    required this.hoaId,
    required this.roleId,
  });

  final String userId;
  final String hoaId;
  final int roleId;
}

String? _digitsOnly(String? value) {
  if (value == null) return null;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : digits;
}

String? _emptyToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
