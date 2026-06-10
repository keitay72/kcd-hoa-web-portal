-- =========================================================
-- Migration: 0021_user_tenant_roles_compatibility.sql
-- Purpose: Add SaaS-correct tenant-role compatibility view over legacy user_platform_roles
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- The physical table remains public.user_platform_roles during the SaaS
-- transition to avoid destabilizing existing RLS policies, Edge Functions,
-- and Admin Web App writes. New code should prefer this SaaS-correct view name.
drop view if exists public.user_tenant_roles;

create view public.user_tenant_roles
with (security_invoker = true)
as
select
  upr.user_id,
  upr.tenant_id,
  upr.role_id,
  upr.created_at,
  upr.assigned_by
from public.user_platform_roles upr;

grant select, insert, update, delete on public.user_tenant_roles to authenticated;


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

drop trigger if exists trg_user_platform_roles_tenant_role on public.user_platform_roles;
create trigger trg_user_platform_roles_tenant_role
before insert or update on public.user_platform_roles
for each row execute function public.enforce_user_platform_role_is_tenant_role();

revoke all on function public.enforce_user_platform_role_is_tenant_role() from public, anon, authenticated;

comment on view public.user_tenant_roles is
  'SaaS-correct compatibility view for tenant-scoped role assignments. Backed by legacy public.user_platform_roles during the transition.';

comment on table public.user_platform_roles is
  'Deprecated physical storage for tenant-scoped role assignments. Prefer public.user_tenant_roles in new app code and documentation until the physical table is renamed.';

comment on column public.user_platform_roles.tenant_id is
  'Waste-management tenant scope for this tenant role assignment.';

comment on column public.user_platform_roles.role_id is
  'Tenant role assignment. Expected target roles: tenant_admin, tenant_manager, tenant_csr, tenant_dispatch, and temporary legacy aliases sys_admin/mgmt.';

comment on function public.enforce_user_platform_role_is_tenant_role() is
  'Ensures tenant-scoped role assignment storage cannot contain global platform roles, HOA roles, or resident roles.';

commit;
