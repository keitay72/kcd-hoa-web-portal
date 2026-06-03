-- =========================================================
-- Migration: 0012_seed_roles_permissions.sql
-- Purpose: Seed Phase 1 role, permission, and role-permission catalog data
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

insert into public.roles (code, name, description, is_system)
values
  ('resident', 'Resident', 'Verified HOA resident', true),
  ('hoa_board', 'HOA Board Member', 'HOA board member with HOA-scoped privileges', true),
  ('hoa_manager', 'HOA Manager', 'HOA property manager with HOA-scoped privileges', true),
  ('csr', 'Customer Service', 'KC Disposal customer service staff', true),
  ('dispatch', 'Dispatch', 'KC Disposal dispatch staff', true),
  ('mgmt', 'Management', 'KC Disposal management staff', true),
  ('sys_admin', 'System Admin', 'KC Disposal system administrator', true)
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
    ('resident', 'profiles.read'),
    ('resident', 'profiles.update'),
    ('resident', 'hoa.read'),
    ('resident', 'addresses.read'),
    ('resident', 'verification.read'),
    ('resident', 'announcements.read'),
    ('resident', 'documents.read'),
    ('resident', 'schedules.read'),
    ('resident', 'tickets.create'),
    ('resident', 'tickets.read'),
    ('resident', 'ticket_attachments.create'),
    ('resident', 'ticket_attachments.read'),

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

    ('csr', 'profiles.read'),
    ('csr', 'profiles.update'),
    ('csr', 'hoa.read'),
    ('csr', 'hoa.manage'),
    ('csr', 'addresses.read'),
    ('csr', 'addresses.manage'),
    ('csr', 'verification.read'),
    ('csr', 'verification.manage'),
    ('csr', 'announcements.read'),
    ('csr', 'documents.read'),
    ('csr', 'schedules.read'),
    ('csr', 'tickets.read'),
    ('csr', 'tickets.update'),
    ('csr', 'ticket_attachments.read'),
    ('csr', 'audit.write'),
    ('csr', 'roles.read'),

    ('dispatch', 'profiles.read'),
    ('dispatch', 'hoa.read'),
    ('dispatch', 'addresses.read'),
    ('dispatch', 'tickets.read'),
    ('dispatch', 'tickets.update'),
    ('dispatch', 'ticket_attachments.read'),
    ('dispatch', 'roles.read'),

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
