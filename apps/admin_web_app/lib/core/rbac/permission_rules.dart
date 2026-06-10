class AdminPermissionRule {
  const AdminPermissionRule.any(
    this.permissions, {
    this.roleCodes = const {},
  });

  final Set<String> permissions;
  final Set<String> roleCodes;

  bool get isOpen => permissions.isEmpty && roleCodes.isEmpty;
}

class AdminPermissions {
  static const dashboard = AdminPermissionRule.any({});
  static const hoaScoped = AdminPermissionRule.any(
    {'hoa.read'},
    roleCodes: {'hoa_manager', 'hoa_board'},
  );
  static const hoaDocuments = AdminPermissionRule.any(
    {'documents.read'},
    roleCodes: {'hoa_manager', 'hoa_board'},
  );
  static const hoaAnnouncements = AdminPermissionRule.any(
    {'announcements.read'},
    roleCodes: {'hoa_manager', 'hoa_board'},
  );
  static const hoaSchedules = AdminPermissionRule.any(
    {'schedules.read'},
    roleCodes: {'hoa_manager', 'hoa_board'},
  );
  static const hoaTickets = AdminPermissionRule.any(
    {'tickets.read'},
    roleCodes: {'hoa_manager', 'hoa_board'},
  );
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
  static const rolesManage = AdminPermissionRule.any({'roles.manage'});
  static const tenantRead = AdminPermissionRule.any(
    {'tenants.read'},
    roleCodes: {'platform_owner', 'platform_admin', 'platform_support', 'platform_sales'},
  );
  static const tenantManage = AdminPermissionRule.any(
    {'tenants.manage'},
    roleCodes: {'platform_owner', 'platform_admin'},
  );
  static const commercialCatalog = AdminPermissionRule.any(
    {'billing.manage'},
    roleCodes: {'platform_owner', 'platform_admin'},
  );
}
