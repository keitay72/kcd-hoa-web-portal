-- =========================================================
-- Migration: 0022_role_catalog_scope_cleanup.sql
-- Purpose: Add role scope/status metadata and remove KC-specific role descriptions
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.roles
  add column if not exists role_scope text not null default 'tenant',
  add column if not exists lifecycle_status text not null default 'active';

alter table public.roles
  drop constraint if exists roles_role_scope_valid;

alter table public.roles
  add constraint roles_role_scope_valid
  check (role_scope in ('platform', 'tenant', 'hoa', 'resident'));

alter table public.roles
  drop constraint if exists roles_lifecycle_status_valid;

alter table public.roles
  add constraint roles_lifecycle_status_valid
  check (lifecycle_status in ('active', 'deprecated'));

update public.roles
set
  role_scope = 'resident',
  lifecycle_status = 'active',
  description = 'Verified HOA resident.'
where code = 'hoa_resident';

update public.roles
set
  role_scope = 'hoa',
  lifecycle_status = 'active',
  description = 'HOA board member with HOA-scoped portal access.'
where code = 'hoa_board';

update public.roles
set
  role_scope = 'hoa',
  lifecycle_status = 'active',
  description = 'HOA manager with HOA-scoped management access.'
where code = 'hoa_manager';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'active',
  description = 'Disposal tenant customer service staff.'
where code = 'tenant_csr';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'active',
  description = 'Disposal tenant dispatch staff.'
where code = 'tenant_dispatch';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'deprecated',
  name = 'Management (Deprecated)',
  description = 'Deprecated tenant management alias. Use tenant_manager for new assignments.'
where code = 'mgmt';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'deprecated',
  name = 'System Admin (Deprecated)',
  description = 'Deprecated tenant administrator alias. Use tenant_admin for new assignments.'
where code = 'sys_admin';

update public.roles
set
  role_scope = 'platform',
  lifecycle_status = 'active',
  description = 'SaaS platform owner with full global authority.'
where code = 'platform_owner';

update public.roles
set
  role_scope = 'platform',
  lifecycle_status = 'active',
  description = 'SaaS platform administrator with global tenant and user administration access.'
where code = 'platform_admin';

update public.roles
set
  role_scope = 'platform',
  lifecycle_status = 'active',
  description = 'SaaS platform support user with tenant support and troubleshooting access.'
where code = 'platform_support';

update public.roles
set
  role_scope = 'platform',
  lifecycle_status = 'active',
  description = 'SaaS platform sales user with tenant commercial and onboarding visibility.'
where code = 'platform_sales';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'active',
  description = 'Disposal tenant administrator.'
where code = 'tenant_admin';

update public.roles
set
  role_scope = 'tenant',
  lifecycle_status = 'active',
  description = 'Disposal tenant manager.'
where code = 'tenant_manager';

create index if not exists idx_roles_scope_status
  on public.roles(role_scope, lifecycle_status);

comment on column public.roles.role_scope is
  'Authorization scope for this role: platform, tenant, hoa, or resident.';

comment on column public.roles.lifecycle_status is
  'Role catalog lifecycle status. Deprecated roles are retained for legacy assignments but should not be used for new assignments.';

commit;
