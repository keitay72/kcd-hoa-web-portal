-- =========================================================
-- Migration: 0042_add_tenant_owner_role.sql
-- Purpose: Add tenant owner as the top tenant-scoped role
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

insert into public.roles (code, name, description, is_system, role_scope, lifecycle_status)
values (
  'tenant_owner',
  'Tenant Owner',
  'Primary owner for a waste-management tenant account with full tenant-scoped authority.',
  true,
  'tenant',
  'active'
)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  is_system = excluded.is_system,
  role_scope = excluded.role_scope,
  lifecycle_status = excluded.lifecycle_status;

-- Tenant Owner should start with the same operating permissions as Tenant Admin.
insert into public.role_permissions (role_id, permission_id)
select owner_role.id, rp.permission_id
from public.roles owner_role
join public.roles admin_role on admin_role.code = 'tenant_admin'
join public.role_permissions rp on rp.role_id = admin_role.id
where owner_role.code = 'tenant_owner'
on conflict (role_id, permission_id) do nothing;

create or replace function public.is_tenant_admin(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_tenant_role(
    _tenant_id,
    array['tenant_owner', 'tenant_admin', 'sys_admin']
  );
$$;

create or replace function public.is_tenant_staff(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_tenant_role(
    _tenant_id,
    array['tenant_owner', 'tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch', 'sys_admin', 'mgmt']
  );
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

  if role_code not in ('tenant_owner', 'tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch', 'sys_admin', 'mgmt') then
    raise exception 'role_id % is %, but user_platform_roles/user_tenant_roles only allows tenant roles', new.role_id, role_code;
  end if;

  return new;
end;
$$;

revoke all on function public.is_tenant_admin(uuid) from public, anon, authenticated;
revoke all on function public.is_tenant_staff(uuid) from public, anon, authenticated;
revoke all on function public.enforce_user_platform_role_is_tenant_role() from public, anon, authenticated;

grant execute on function public.is_tenant_admin(uuid) to authenticated;
grant execute on function public.is_tenant_staff(uuid) to authenticated;

comment on function public.is_tenant_admin(uuid) is
  'Returns true for tenant_owner, tenant_admin, or legacy sys_admin in the given tenant.';

comment on function public.is_tenant_staff(uuid) is
  'Returns true for tenant staff roles: tenant_owner, tenant_admin, tenant_manager, tenant_csr, tenant_dispatch, and legacy sys_admin/mgmt.';

comment on function public.enforce_user_platform_role_is_tenant_role() is
  'Ensures tenant-scoped role assignment storage cannot contain global platform roles, community roles, or customer roles.';

commit;
