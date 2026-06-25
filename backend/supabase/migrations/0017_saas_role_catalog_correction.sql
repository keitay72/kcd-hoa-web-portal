-- =========================================================
-- Migration: 0017_saas_role_catalog_correction.sql
-- Purpose: Add SaaS platform and tenant role catalog entries for multi-tenant readiness
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- Add SaaS-ready roles without removing legacy KC Disposal roles.
-- Legacy mapping:
--   sys_admin -> tenant_admin
--   mgmt      -> tenant_manager
insert into public.roles (code, name, description, is_system)
values
  ('platform_owner', 'Platform Owner', 'SaaS platform owner with full global authority across all tenants, billing, support, and settings', true),
  ('platform_admin', 'Platform Admin', 'SaaS platform administrator with global tenant, support, billing, and operational access', true),
  ('platform_support', 'Platform Support', 'SaaS platform support user with audited cross-tenant support visibility', true),
  ('platform_sales', 'Platform Sales', 'SaaS platform sales user with tenant commercial and onboarding visibility', true),
  ('tenant_admin', 'Tenant Admin', 'Waste-management tenant administrator; SaaS replacement for legacy sys_admin tenant role', true),
  ('tenant_manager', 'Tenant Manager', 'Waste-management tenant manager; SaaS replacement for legacy mgmt tenant role', true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  is_system = excluded.is_system;

-- Add SaaS, billing, subscription, add-on, communication, and tenant/platform permissions.
insert into public.permissions (code, name, description)
values
  ('tenants.read', 'Read tenants', 'Read waste-management tenant records'),
  ('tenants.manage', 'Manage tenants', 'Create and update waste-management tenant records'),
  ('tenant.users.read', 'Read tenant users', 'Read users assigned to a waste-management tenant'),
  ('tenant.users.manage', 'Manage tenant users', 'Invite, update, deactivate, and assign tenant-scoped users'),
  ('tenant.analytics.read', 'Read tenant analytics', 'Read analytics for a waste-management tenant'),
  ('tenant.settings.manage', 'Manage tenant settings', 'Manage waste-management tenant settings, branding, and configuration'),

  ('platform.tenants.read', 'Read platform tenants', 'Read all tenants as a SaaS platform operator'),
  ('platform.tenants.manage', 'Manage platform tenants', 'Create, update, suspend, and configure tenants as a SaaS platform operator'),
  ('platform.users.read', 'Read platform users', 'Read SaaS platform operator users and cross-tenant user context'),
  ('platform.users.manage', 'Manage platform users', 'Manage SaaS platform operator users and global role assignments'),
  ('platform.analytics.read', 'Read platform analytics', 'Read global SaaS platform analytics across tenants'),
  ('platform.support.read', 'Read platform support', 'Read cross-tenant support context for platform support workflows'),
  ('platform.support.manage', 'Manage platform support', 'Manage cross-tenant support workflows and escalations'),
  ('platform.audit.read', 'Read platform audit logs', 'Read global SaaS platform audit logs'),
  ('platform.settings.manage', 'Manage platform settings', 'Manage SaaS platform-wide settings'),

  ('billing.read', 'Read billing', 'Read tenant billing and subscription records'),
  ('billing.manage', 'Manage billing', 'Manage tenant billing records and payment provider configuration'),
  ('plans.read', 'Read plans', 'Read subscription plan and pricing catalog'),
  ('plans.manage', 'Manage plans', 'Create and update subscription plans'),
  ('subscriptions.read', 'Read subscriptions', 'Read tenant subscription status and subscription items'),
  ('subscriptions.manage', 'Manage subscriptions', 'Create and update tenant subscriptions and subscription items'),
  ('addons.read', 'Read add-ons', 'Read tenant add-on catalog and tenant add-on state'),
  ('addons.manage', 'Manage add-ons', 'Enable, disable, and configure tenant add-ons'),
  ('rates.read', 'Read rates', 'Read subscription rates and tenant pricing'),
  ('rates.manage', 'Manage rates', 'Set subscription rates, discounts, and commercial pricing'),
  ('communications.read', 'Read communications settings', 'Read tenant email, SMS, and notification settings'),
  ('communications.manage', 'Manage communications settings', 'Manage tenant email, SMS, and notification settings')
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description;

with role_permission_map(role_code, permission_code) as (
  values
    -- Platform owner: all existing app permissions plus all SaaS/commercial permissions.
    ('platform_owner', 'profiles.read'),
    ('platform_owner', 'profiles.update'),
    ('platform_owner', 'hoa.read'),
    ('platform_owner', 'hoa.manage'),
    ('platform_owner', 'addresses.read'),
    ('platform_owner', 'addresses.manage'),
    ('platform_owner', 'verification.read'),
    ('platform_owner', 'verification.manage'),
    ('platform_owner', 'announcements.read'),
    ('platform_owner', 'announcements.manage'),
    ('platform_owner', 'documents.read'),
    ('platform_owner', 'documents.manage'),
    ('platform_owner', 'schedules.read'),
    ('platform_owner', 'schedules.manage'),
    ('platform_owner', 'tickets.create'),
    ('platform_owner', 'tickets.read'),
    ('platform_owner', 'tickets.update'),
    ('platform_owner', 'ticket_attachments.create'),
    ('platform_owner', 'ticket_attachments.read'),
    ('platform_owner', 'audit.read'),
    ('platform_owner', 'audit.write'),
    ('platform_owner', 'roles.read'),
    ('platform_owner', 'roles.manage'),
    ('platform_owner', 'tenants.read'),
    ('platform_owner', 'tenants.manage'),
    ('platform_owner', 'tenant.users.read'),
    ('platform_owner', 'tenant.users.manage'),
    ('platform_owner', 'tenant.analytics.read'),
    ('platform_owner', 'tenant.settings.manage'),
    ('platform_owner', 'platform.tenants.read'),
    ('platform_owner', 'platform.tenants.manage'),
    ('platform_owner', 'platform.users.read'),
    ('platform_owner', 'platform.users.manage'),
    ('platform_owner', 'platform.analytics.read'),
    ('platform_owner', 'platform.support.read'),
    ('platform_owner', 'platform.support.manage'),
    ('platform_owner', 'platform.audit.read'),
    ('platform_owner', 'platform.settings.manage'),
    ('platform_owner', 'billing.read'),
    ('platform_owner', 'billing.manage'),
    ('platform_owner', 'plans.read'),
    ('platform_owner', 'plans.manage'),
    ('platform_owner', 'subscriptions.read'),
    ('platform_owner', 'subscriptions.manage'),
    ('platform_owner', 'addons.read'),
    ('platform_owner', 'addons.manage'),
    ('platform_owner', 'rates.read'),
    ('platform_owner', 'rates.manage'),
    ('platform_owner', 'communications.read'),
    ('platform_owner', 'communications.manage'),

    -- Platform admin: operationally equivalent to owner for now, except intended to be policy-limited later if needed.
    ('platform_admin', 'profiles.read'),
    ('platform_admin', 'profiles.update'),
    ('platform_admin', 'hoa.read'),
    ('platform_admin', 'hoa.manage'),
    ('platform_admin', 'addresses.read'),
    ('platform_admin', 'addresses.manage'),
    ('platform_admin', 'verification.read'),
    ('platform_admin', 'verification.manage'),
    ('platform_admin', 'announcements.read'),
    ('platform_admin', 'announcements.manage'),
    ('platform_admin', 'documents.read'),
    ('platform_admin', 'documents.manage'),
    ('platform_admin', 'schedules.read'),
    ('platform_admin', 'schedules.manage'),
    ('platform_admin', 'tickets.create'),
    ('platform_admin', 'tickets.read'),
    ('platform_admin', 'tickets.update'),
    ('platform_admin', 'ticket_attachments.create'),
    ('platform_admin', 'ticket_attachments.read'),
    ('platform_admin', 'audit.read'),
    ('platform_admin', 'audit.write'),
    ('platform_admin', 'roles.read'),
    ('platform_admin', 'roles.manage'),
    ('platform_admin', 'tenants.read'),
    ('platform_admin', 'tenants.manage'),
    ('platform_admin', 'tenant.users.read'),
    ('platform_admin', 'tenant.users.manage'),
    ('platform_admin', 'tenant.analytics.read'),
    ('platform_admin', 'tenant.settings.manage'),
    ('platform_admin', 'platform.tenants.read'),
    ('platform_admin', 'platform.tenants.manage'),
    ('platform_admin', 'platform.users.read'),
    ('platform_admin', 'platform.users.manage'),
    ('platform_admin', 'platform.analytics.read'),
    ('platform_admin', 'platform.support.read'),
    ('platform_admin', 'platform.support.manage'),
    ('platform_admin', 'platform.audit.read'),
    ('platform_admin', 'platform.settings.manage'),
    ('platform_admin', 'billing.read'),
    ('platform_admin', 'billing.manage'),
    ('platform_admin', 'plans.read'),
    ('platform_admin', 'plans.manage'),
    ('platform_admin', 'subscriptions.read'),
    ('platform_admin', 'subscriptions.manage'),
    ('platform_admin', 'addons.read'),
    ('platform_admin', 'addons.manage'),
    ('platform_admin', 'rates.read'),
    ('platform_admin', 'rates.manage'),
    ('platform_admin', 'communications.read'),
    ('platform_admin', 'communications.manage'),

    -- Platform support: cross-tenant support visibility without commercial rate/plan mutation.
    ('platform_support', 'profiles.read'),
    ('platform_support', 'hoa.read'),
    ('platform_support', 'addresses.read'),
    ('platform_support', 'verification.read'),
    ('platform_support', 'announcements.read'),
    ('platform_support', 'documents.read'),
    ('platform_support', 'schedules.read'),
    ('platform_support', 'tickets.read'),
    ('platform_support', 'tickets.update'),
    ('platform_support', 'ticket_attachments.read'),
    ('platform_support', 'audit.read'),
    ('platform_support', 'roles.read'),
    ('platform_support', 'tenants.read'),
    ('platform_support', 'tenant.users.read'),
    ('platform_support', 'tenant.analytics.read'),
    ('platform_support', 'platform.tenants.read'),
    ('platform_support', 'platform.users.read'),
    ('platform_support', 'platform.support.read'),
    ('platform_support', 'platform.support.manage'),
    ('platform_support', 'platform.audit.read'),
    ('platform_support', 'billing.read'),
    ('platform_support', 'plans.read'),
    ('platform_support', 'subscriptions.read'),
    ('platform_support', 'addons.read'),
    ('platform_support', 'communications.read'),

    -- Platform sales: tenant commercial visibility and subscription/add-on setup support.
    ('platform_sales', 'profiles.read'),
    ('platform_sales', 'hoa.read'),
    ('platform_sales', 'addresses.read'),
    ('platform_sales', 'tickets.read'),
    ('platform_sales', 'roles.read'),
    ('platform_sales', 'tenants.read'),
    ('platform_sales', 'tenant.analytics.read'),
    ('platform_sales', 'platform.tenants.read'),
    ('platform_sales', 'platform.analytics.read'),
    ('platform_sales', 'billing.read'),
    ('platform_sales', 'plans.read'),
    ('platform_sales', 'subscriptions.read'),
    ('platform_sales', 'subscriptions.manage'),
    ('platform_sales', 'addons.read'),
    ('platform_sales', 'addons.manage'),
    ('platform_sales', 'rates.read'),
    ('platform_sales', 'communications.read'),

    -- Tenant admin: SaaS replacement for legacy sys_admin, permission-compatible for now.
    ('tenant_admin', 'profiles.read'),
    ('tenant_admin', 'profiles.update'),
    ('tenant_admin', 'hoa.read'),
    ('tenant_admin', 'hoa.manage'),
    ('tenant_admin', 'addresses.read'),
    ('tenant_admin', 'addresses.manage'),
    ('tenant_admin', 'verification.read'),
    ('tenant_admin', 'verification.manage'),
    ('tenant_admin', 'announcements.read'),
    ('tenant_admin', 'announcements.manage'),
    ('tenant_admin', 'documents.read'),
    ('tenant_admin', 'documents.manage'),
    ('tenant_admin', 'schedules.read'),
    ('tenant_admin', 'schedules.manage'),
    ('tenant_admin', 'tickets.create'),
    ('tenant_admin', 'tickets.read'),
    ('tenant_admin', 'tickets.update'),
    ('tenant_admin', 'ticket_attachments.create'),
    ('tenant_admin', 'ticket_attachments.read'),
    ('tenant_admin', 'audit.read'),
    ('tenant_admin', 'audit.write'),
    ('tenant_admin', 'roles.read'),
    ('tenant_admin', 'roles.manage'),
    ('tenant_admin', 'tenants.read'),
    ('tenant_admin', 'tenant.users.read'),
    ('tenant_admin', 'tenant.users.manage'),
    ('tenant_admin', 'tenant.analytics.read'),
    ('tenant_admin', 'tenant.settings.manage'),
    ('tenant_admin', 'billing.read'),
    ('tenant_admin', 'plans.read'),
    ('tenant_admin', 'subscriptions.read'),
    ('tenant_admin', 'addons.read'),
    ('tenant_admin', 'communications.read'),
    ('tenant_admin', 'communications.manage'),

    -- Tenant manager: SaaS replacement for legacy mgmt, permission-compatible plus tenant analytics/settings read support.
    ('tenant_manager', 'profiles.read'),
    ('tenant_manager', 'hoa.read'),
    ('tenant_manager', 'addresses.read'),
    ('tenant_manager', 'verification.read'),
    ('tenant_manager', 'announcements.read'),
    ('tenant_manager', 'documents.read'),
    ('tenant_manager', 'schedules.read'),
    ('tenant_manager', 'tickets.read'),
    ('tenant_manager', 'ticket_attachments.read'),
    ('tenant_manager', 'audit.read'),
    ('tenant_manager', 'roles.read'),
    ('tenant_manager', 'tenants.read'),
    ('tenant_manager', 'tenant.users.read'),
    ('tenant_manager', 'tenant.analytics.read'),
    ('tenant_manager', 'communications.read')
)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from role_permission_map rpm
join public.roles r on r.code = rpm.role_code
join public.permissions p on p.code = rpm.permission_code
on conflict (role_id, permission_id) do nothing;

-- Preserve current access while creating the new SaaS role layer by copying
-- existing legacy assignments into their target tenant-role equivalents.
insert into public.user_platform_roles (user_id, tenant_id, role_id, assigned_by)
select upr.user_id, upr.tenant_id, tenant_admin_role.id, upr.assigned_by
from public.user_platform_roles upr
join public.roles legacy_role on legacy_role.id = upr.role_id
join public.roles tenant_admin_role on tenant_admin_role.code = 'tenant_admin'
where legacy_role.code = 'sys_admin'
on conflict (user_id, tenant_id, role_id) do nothing;

insert into public.user_platform_roles (user_id, tenant_id, role_id, assigned_by)
select upr.user_id, upr.tenant_id, tenant_manager_role.id, upr.assigned_by
from public.user_platform_roles upr
join public.roles legacy_role on legacy_role.id = upr.role_id
join public.roles tenant_manager_role on tenant_manager_role.code = 'tenant_manager'
where legacy_role.code = 'mgmt'
on conflict (user_id, tenant_id, role_id) do nothing;

commit;
