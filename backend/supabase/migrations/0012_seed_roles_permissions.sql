-- =========================================================
-- Migration: 0012_seed_roles_permissions.sql
-- Purpose: Seed Phase 1 role, permission, and role-permission catalog data
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

insert into public.roles (code, name, description, is_system)
values
  ('hoa_resident', 'HOA Resident', 'Verified HOA resident.', true),
  ('hoa_board', 'HOA Board Member', 'HOA board member with HOA-scoped privileges', true),
  ('hoa_manager', 'HOA Manager', 'HOA property manager with HOA-scoped privileges', true),
  ('tenant_csr', 'Tenant Customer Service', 'Disposal tenant customer service staff.', true),
  ('tenant_dispatch', 'Tenant Dispatch', 'Disposal tenant dispatch staff.', true),
  ('mgmt', 'Management (Deprecated)', 'Deprecated tenant management alias. Use tenant_manager for new assignments.', true),
  ('sys_admin', 'System Admin (Deprecated)', 'Deprecated tenant administrator alias. Use tenant_admin for new assignments.', true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  is_system = excluded.is_system;

insert into public.permissions (code, name, description)
values
  ('profiles.read', 'Read profiles', 'Read user profile records'),
  ('profiles.update', 'Update profiles', 'Update user profile records'),
  ('hoa.read', 'Read HOA records', 'Read HOA community records'),
  ('hoa.manage', 'Manage HOA records', 'Create and update HOA community records'),
  ('addresses.read', 'Read HOA addresses', 'Read HOA address registry records'),
  ('addresses.manage', 'Manage HOA addresses', 'Create and update HOA address registry records'),
  ('verification.read', 'Read verification records', 'Read resident verification records'),
  ('verification.manage', 'Manage verification records', 'Update resident verification and activation code state'),
  ('announcements.read', 'Read announcements', 'Read published HOA announcements'),
  ('announcements.manage', 'Manage announcements', 'Create and update HOA announcements'),
  ('documents.read', 'Read documents', 'Read HOA document metadata and files'),
  ('documents.manage', 'Manage documents', 'Create and update HOA document metadata and files'),
  ('schedules.read', 'Read schedules', 'Read service schedules'),
  ('schedules.manage', 'Manage schedules', 'Create and update service schedules'),
  ('tickets.create', 'Create tickets', 'Create resident service tickets'),
  ('tickets.read', 'Read tickets', 'Read authorized service tickets'),
  ('tickets.update', 'Update tickets', 'Update service ticket status and details'),
  ('ticket_attachments.create', 'Create ticket attachments', 'Upload ticket attachments'),
  ('ticket_attachments.read', 'Read ticket attachments', 'Read authorized ticket attachments'),
  ('audit.read', 'Read audit logs', 'Read admin audit logs'),
  ('audit.write', 'Write audit logs', 'Create admin audit log records'),
  ('roles.read', 'Read roles and permissions', 'Read role and permission catalog'),
  ('roles.manage', 'Manage roles and permissions', 'Manage role assignments and permission catalog')
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description;

with role_permission_map(role_code, permission_code) as (
  values
    ('hoa_resident', 'profiles.read'),
    ('hoa_resident', 'profiles.update'),
    ('hoa_resident', 'hoa.read'),
    ('hoa_resident', 'addresses.read'),
    ('hoa_resident', 'verification.read'),
    ('hoa_resident', 'announcements.read'),
    ('hoa_resident', 'documents.read'),
    ('hoa_resident', 'schedules.read'),
    ('hoa_resident', 'tickets.create'),
    ('hoa_resident', 'tickets.read'),
    ('hoa_resident', 'ticket_attachments.create'),
    ('hoa_resident', 'ticket_attachments.read'),

    ('hoa_board', 'profiles.read'),
    ('hoa_board', 'hoa.read'),
    ('hoa_board', 'addresses.read'),
    ('hoa_board', 'verification.read'),
    ('hoa_board', 'announcements.read'),
    ('hoa_board', 'announcements.manage'),
    ('hoa_board', 'documents.read'),
    ('hoa_board', 'documents.manage'),
    ('hoa_board', 'schedules.read'),
    ('hoa_board', 'tickets.read'),
    ('hoa_board', 'ticket_attachments.read'),

    ('hoa_manager', 'profiles.read'),
    ('hoa_manager', 'hoa.read'),
    ('hoa_manager', 'addresses.read'),
    ('hoa_manager', 'verification.read'),
    ('hoa_manager', 'announcements.read'),
    ('hoa_manager', 'announcements.manage'),
    ('hoa_manager', 'documents.read'),
    ('hoa_manager', 'documents.manage'),
    ('hoa_manager', 'schedules.read'),
    ('hoa_manager', 'tickets.read'),
    ('hoa_manager', 'ticket_attachments.read'),

    ('tenant_csr', 'profiles.read'),
    ('tenant_csr', 'profiles.update'),
    ('tenant_csr', 'hoa.read'),
    ('tenant_csr', 'hoa.manage'),
    ('tenant_csr', 'addresses.read'),
    ('tenant_csr', 'addresses.manage'),
    ('tenant_csr', 'verification.read'),
    ('tenant_csr', 'verification.manage'),
    ('tenant_csr', 'announcements.read'),
    ('tenant_csr', 'documents.read'),
    ('tenant_csr', 'schedules.read'),
    ('tenant_csr', 'tickets.read'),
    ('tenant_csr', 'tickets.update'),
    ('tenant_csr', 'ticket_attachments.read'),
    ('tenant_csr', 'audit.write'),
    ('tenant_csr', 'roles.read'),

    ('tenant_dispatch', 'profiles.read'),
    ('tenant_dispatch', 'hoa.read'),
    ('tenant_dispatch', 'addresses.read'),
    ('tenant_dispatch', 'tickets.read'),
    ('tenant_dispatch', 'tickets.update'),
    ('tenant_dispatch', 'ticket_attachments.read'),
    ('tenant_dispatch', 'roles.read'),

    ('mgmt', 'profiles.read'),
    ('mgmt', 'hoa.read'),
    ('mgmt', 'addresses.read'),
    ('mgmt', 'verification.read'),
    ('mgmt', 'announcements.read'),
    ('mgmt', 'documents.read'),
    ('mgmt', 'schedules.read'),
    ('mgmt', 'tickets.read'),
    ('mgmt', 'ticket_attachments.read'),
    ('mgmt', 'audit.read'),
    ('mgmt', 'roles.read'),

    ('sys_admin', 'profiles.read'),
    ('sys_admin', 'profiles.update'),
    ('sys_admin', 'hoa.read'),
    ('sys_admin', 'hoa.manage'),
    ('sys_admin', 'addresses.read'),
    ('sys_admin', 'addresses.manage'),
    ('sys_admin', 'verification.read'),
    ('sys_admin', 'verification.manage'),
    ('sys_admin', 'announcements.read'),
    ('sys_admin', 'announcements.manage'),
    ('sys_admin', 'documents.read'),
    ('sys_admin', 'documents.manage'),
    ('sys_admin', 'schedules.read'),
    ('sys_admin', 'schedules.manage'),
    ('sys_admin', 'tickets.create'),
    ('sys_admin', 'tickets.read'),
    ('sys_admin', 'tickets.update'),
    ('sys_admin', 'ticket_attachments.create'),
    ('sys_admin', 'ticket_attachments.read'),
    ('sys_admin', 'audit.read'),
    ('sys_admin', 'audit.write'),
    ('sys_admin', 'roles.read'),
    ('sys_admin', 'roles.manage')
)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from role_permission_map rpm
join public.roles r on r.code = rpm.role_code
join public.permissions p on p.code = rpm.permission_code
on conflict (role_id, permission_id) do nothing;

commit;
