const devSecurityBypassEnabled = bool.fromEnvironment(
  'KCD_DEV_SECURITY_BYPASS',
  defaultValue: false,
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
  'customer_accounts.manage',
  'customer_accounts.read',
  'dashboard.read',
  'documents.manage',
  'documents.read',
  'hoa.manage',
  'hoa.read',
  'roles.manage',
  'schedules.manage',
  'schedules.read',
  'service_locations.manage',
  'service_locations.read',
  'tenants.manage',
  'tenants.read',
  'tickets.manage',
  'tickets.read',
  'tickets.update',
  'verification.manage',
  'verification.read',
};
