class AdminPermissionRule {
  const AdminPermissionRule.any(this.permissions);

  final Set<String> permissions;

  bool get isOpen => permissions.isEmpty;
}

class AdminPermissions {
  static const dashboard = AdminPermissionRule.any({});
  static const hoaRead = AdminPermissionRule.any({'hoa.read'});
  static const addressRead = AdminPermissionRule.any({'addresses.read'});
  static const activationCodes = AdminPermissionRule.any({'verification.manage'});
  static const verificationRead = AdminPermissionRule.any({'verification.read'});
  static const announcementsRead = AdminPermissionRule.any({'announcements.read'});
  static const documentsRead = AdminPermissionRule.any({'documents.read'});
  static const schedulesRead = AdminPermissionRule.any({'schedules.read'});
  static const ticketsRead = AdminPermissionRule.any({'tickets.read'});
  static const ticketsUpdate = AdminPermissionRule.any({'tickets.update'});
  static const auditRead = AdminPermissionRule.any({'audit.read'});
}
