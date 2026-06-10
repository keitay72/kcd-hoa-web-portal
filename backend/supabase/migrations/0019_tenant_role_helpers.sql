-- =========================================================
-- Migration: 0019_tenant_role_helpers.sql
-- Purpose: Add tenant-aware helper functions for SaaS authorization vocabulary
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create or replace function public.tenant_role_codes(_tenant_id uuid)
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(array_agg(distinct r.code), '{}')::text[]
  from public.user_platform_roles upr
  join public.roles r on r.id = upr.role_id
  where upr.user_id = auth.uid()
    and upr.tenant_id = _tenant_id;
$$;

create or replace function public.has_tenant_role(_tenant_id uuid, _role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select _role = any(public.tenant_role_codes(_tenant_id));
$$;

create or replace function public.has_any_tenant_role(_tenant_id uuid, _roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from unnest(public.tenant_role_codes(_tenant_id)) role_code
    where role_code = any(_roles)
  );
$$;

create or replace function public.is_tenant_admin(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_tenant_role(_tenant_id, array['tenant_admin', 'sys_admin']);
$$;

create or replace function public.is_tenant_manager(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_tenant_role(_tenant_id, array['tenant_manager', 'mgmt']);
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
    array['tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch', 'sys_admin', 'mgmt']
  );
$$;

create or replace function public.can_access_tenant(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_platform_operator()
    or public.is_tenant_staff(_tenant_id);
$$;

create or replace function public.can_manage_tenant(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_platform_owner()
    or public.is_platform_admin()
    or public.is_tenant_admin(_tenant_id);
$$;

create or replace function public.hoa_tenant_id(_hoa_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select hc.tenant_id
  from public.hoa_communities hc
  where hc.id = _hoa_id;
$$;

-- SECURITY DEFINER functions should not inherit PostgreSQL's default PUBLIC
-- execute privilege. Grant only roles that need them for app queries/RLS.
revoke all on function public.tenant_role_codes(uuid) from public, anon, authenticated;
revoke all on function public.has_tenant_role(uuid, text) from public, anon, authenticated;
revoke all on function public.has_any_tenant_role(uuid, text[]) from public, anon, authenticated;
revoke all on function public.is_tenant_admin(uuid) from public, anon, authenticated;
revoke all on function public.is_tenant_manager(uuid) from public, anon, authenticated;
revoke all on function public.is_tenant_staff(uuid) from public, anon, authenticated;
revoke all on function public.can_access_tenant(uuid) from public, anon, authenticated;
revoke all on function public.can_manage_tenant(uuid) from public, anon, authenticated;
revoke all on function public.hoa_tenant_id(uuid) from public, anon, authenticated;

grant execute on function public.tenant_role_codes(uuid) to authenticated;
grant execute on function public.has_tenant_role(uuid, text) to authenticated;
grant execute on function public.has_any_tenant_role(uuid, text[]) to authenticated;
grant execute on function public.is_tenant_admin(uuid) to authenticated;
grant execute on function public.is_tenant_manager(uuid) to authenticated;
grant execute on function public.is_tenant_staff(uuid) to authenticated;
grant execute on function public.can_access_tenant(uuid) to authenticated;
grant execute on function public.can_manage_tenant(uuid) to authenticated;
grant execute on function public.hoa_tenant_id(uuid) to authenticated;

comment on function public.tenant_role_codes(uuid) is
  'Returns tenant-scoped role codes for the current authenticated user. Transitional source table: user_platform_roles.';

comment on function public.has_tenant_role(uuid, text) is
  'Returns true when the current authenticated user has the requested tenant-scoped role in the given tenant.';

comment on function public.has_any_tenant_role(uuid, text[]) is
  'Returns true when the current authenticated user has any requested tenant-scoped role in the given tenant.';

comment on function public.is_tenant_admin(uuid) is
  'Returns true for tenant_admin or legacy sys_admin in the given tenant.';

comment on function public.is_tenant_manager(uuid) is
  'Returns true for tenant_manager or legacy mgmt in the given tenant.';

comment on function public.is_tenant_staff(uuid) is
  'Returns true for tenant staff roles: tenant_admin, tenant_manager, tenant_csr, tenant_dispatch, and legacy sys_admin/mgmt.';

comment on function public.can_access_tenant(uuid) is
  'Returns true when a platform operator or tenant staff user can access the given tenant.';

comment on function public.can_manage_tenant(uuid) is
  'Returns true when a platform owner/admin or tenant admin can manage the given tenant.';

comment on function public.hoa_tenant_id(uuid) is
  'Returns the tenant_id for an HOA community.';

commit;
