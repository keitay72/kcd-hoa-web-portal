-- =========================================================
-- Migration: 0023_canonical_role_code_renames.sql
-- Purpose: Canonicalize role codes after SaaS role scope cleanup
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- These renames match the canonical role codes now used by the SaaS platform:
--   resident -> hoa_resident
--   csr      -> tenant_csr
--   dispatch -> tenant_dispatch
-- Role assignments and role_permissions are FK-backed by role id, so they stay
-- attached to the same rows when the code values are renamed.

update public.roles
set
  code = 'hoa_resident',
  name = 'HOA Resident',
  description = 'Verified HOA resident.',
  role_scope = 'resident',
  lifecycle_status = 'active'
where code = 'resident';

update public.roles
set
  code = 'tenant_csr',
  name = 'Tenant Customer Service',
  description = 'Disposal tenant customer service staff.',
  role_scope = 'tenant',
  lifecycle_status = 'active'
where code = 'csr';

update public.roles
set
  code = 'tenant_dispatch',
  name = 'Tenant Dispatch',
  description = 'Disposal tenant dispatch staff.',
  role_scope = 'tenant',
  lifecycle_status = 'active'
where code = 'dispatch';

-- Idempotent metadata alignment when the codes were already renamed manually.
update public.roles
set
  name = 'HOA Resident',
  description = 'Verified HOA resident.',
  role_scope = 'resident',
  lifecycle_status = 'active'
where code = 'hoa_resident';

update public.roles
set
  name = 'Tenant Customer Service',
  description = 'Disposal tenant customer service staff.',
  role_scope = 'tenant',
  lifecycle_status = 'active'
where code = 'tenant_csr';

update public.roles
set
  name = 'Tenant Dispatch',
  description = 'Disposal tenant dispatch staff.',
  role_scope = 'tenant',
  lifecycle_status = 'active'
where code = 'tenant_dispatch';


-- Refresh helper/trigger code that may have been deployed before the canonical
-- role-code rename.
create or replace function public.is_tenant_staff(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_tenant_role(
    _tenant_id,
    array['tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch', 'sys_admin', 'mgmt']
  );
$$;

create or replace function public.is_kcd_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_platform_role(array['sys_admin', 'tenant_csr', 'tenant_dispatch', 'mgmt']);
$$;

create or replace function public.enforce_user_platform_role_is_tenant_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  role_code text;
begin
  select code
  into role_code
  from public.roles
  where id = new.role_id;

  if role_code is null then
    raise exception 'role_id % does not exist', new.role_id;
  end if;

  if role_code not in ('tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch', 'sys_admin', 'mgmt') then
    raise exception 'role_id % is %, but user_platform_roles/user_tenant_roles only allows tenant roles', new.role_id, role_code;
  end if;

  return new;
end;
$$;

revoke all on function public.is_tenant_staff(uuid) from public, anon, authenticated;
revoke all on function public.is_kcd_staff() from public, anon, authenticated;
revoke all on function public.enforce_user_platform_role_is_tenant_role() from public, anon, authenticated;

grant execute on function public.is_tenant_staff(uuid) to authenticated;
grant execute on function public.is_kcd_staff() to authenticated;

comment on function public.is_tenant_staff(uuid) is
  'Returns true for tenant staff roles: tenant_admin, tenant_manager, tenant_csr, tenant_dispatch, and legacy sys_admin/mgmt.';

comment on function public.enforce_user_platform_role_is_tenant_role() is
  'Ensures tenant-scoped role assignment storage cannot contain global platform roles, HOA roles, or resident roles.';

commit;
