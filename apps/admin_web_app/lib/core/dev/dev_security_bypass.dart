const devSecurityBypassEnabled = bool.fromEnvironment(
  'KCD_DEV_SECURITY_BYPASS',
  defaultValue: true,
);

const devUserId = 'dev-user';
const devUserEmail = 'dev@kcd.local';
const devUserName = 'Development User';
const devTenantId = 'dev-tenant';
const devTenantName = 'Development Tenant';
const devHoaId = 'dev-hoa';
const devHoaName = 'Development HOA';

const devPermissionCodes = {
  'addresses.manage',
  'addresses.read',
  'announcements.manage',
  'announcements.read',
  'audit.read',
  'billing.manage',
  'dashboard.read',
  'documents.manage',
  'documents.read',
  'hoa.manage',
  'hoa.read',
  'roles.manage',
  'schedules.manage',
  'schedules.read',
  'tenants.manage',
  'tenants.read',
  'tickets.manage',
  'tickets.read',
  'tickets.update',
  'verification.manage',
  'verification.read',
};
