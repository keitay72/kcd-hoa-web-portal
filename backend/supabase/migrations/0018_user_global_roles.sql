-- =========================================================
-- Migration: 0018_user_global_roles.sql
-- Purpose: Add true SaaS platform/global role assignments and helper functions
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.user_global_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  created_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,

  primary key (user_id, role_id)
);

create index if not exists idx_user_global_roles_user_id
  on public.user_global_roles(user_id);

create index if not exists idx_user_global_roles_role_id
  on public.user_global_roles(role_id);

comment on table public.user_global_roles is
  'Global SaaS platform role assignments. Use only for platform_owner, platform_admin, platform_support, and platform_sales.';

create or replace function public.enforce_user_global_role_is_platform_role()
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

  if role_code not in ('platform_owner', 'platform_admin', 'platform_support', 'platform_sales') then
    raise exception 'role_id % is %, but user_global_roles only allows platform roles', new.role_id, role_code;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_user_global_roles_platform_role on public.user_global_roles;
create trigger trg_user_global_roles_platform_role
before insert or update on public.user_global_roles
for each row execute function public.enforce_user_global_role_is_platform_role();

create or replace function public.global_role_codes()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(array_agg(distinct r.code), '{}')::text[]
  from public.user_global_roles ugr
  join public.roles r on r.id = ugr.role_id
  where ugr.user_id = auth.uid();
$$;

create or replace function public.has_global_role(_role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select _role = any(public.global_role_codes());
$$;

create or replace function public.has_any_global_role(_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from unnest(public.global_role_codes()) role_code
    where role_code = any(_roles)
  );
$$;

create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_global_role('platform_owner');
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_global_role('platform_admin');
$$;

create or replace function public.is_platform_support()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_global_role('platform_support');
$$;

create or replace function public.is_platform_sales()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_global_role('platform_sales');
$$;

create or replace function public.is_platform_operator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_any_global_role(array[
    'platform_owner',
    'platform_admin',
    'platform_support',
    'platform_sales'
  ]);
$$;

-- Helper used only for bootstrapping global roles while legacy sys_admin still exists.
-- This preserves current KC Disposal admin access until true platform owners/admins are assigned.
create or replace function public.can_manage_global_roles()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_platform_owner()
    or public.is_platform_admin()
    or public.is_sys_admin();
$$;

alter table public.user_global_roles enable row level security;

-- user_global_roles
-- Assigned users can read their own global role assignments.
drop policy if exists user_global_roles_select_self on public.user_global_roles;
create policy user_global_roles_select_self
on public.user_global_roles
for select
to authenticated
using (user_id = auth.uid());

-- Platform operators can read all global role assignments.
drop policy if exists user_global_roles_select_platform_operator on public.user_global_roles;
create policy user_global_roles_select_platform_operator
on public.user_global_roles
for select
to authenticated
using (public.is_platform_operator() or public.is_sys_admin());

-- Platform owners/admins can manage global role assignments. Legacy sys_admin is
-- intentionally included as a temporary bootstrap bridge.
drop policy if exists user_global_roles_manage_platform_admin on public.user_global_roles;
create policy user_global_roles_manage_platform_admin
on public.user_global_roles
for all
to authenticated
using (public.can_manage_global_roles())
with check (public.can_manage_global_roles());

-- SECURITY DEFINER functions should not inherit PostgreSQL's default PUBLIC
-- execute privilege. Grant only roles that need them for app queries/RLS.
revoke all on function public.enforce_user_global_role_is_platform_role() from public, anon, authenticated;
revoke all on function public.global_role_codes() from public, anon, authenticated;
revoke all on function public.has_global_role(text) from public, anon, authenticated;
revoke all on function public.has_any_global_role(text[]) from public, anon, authenticated;
revoke all on function public.is_platform_owner() from public, anon, authenticated;
revoke all on function public.is_platform_admin() from public, anon, authenticated;
revoke all on function public.is_platform_support() from public, anon, authenticated;
revoke all on function public.is_platform_sales() from public, anon, authenticated;
revoke all on function public.is_platform_operator() from public, anon, authenticated;
revoke all on function public.can_manage_global_roles() from public, anon, authenticated;

grant execute on function public.global_role_codes() to authenticated;
grant execute on function public.has_global_role(text) to authenticated;
grant execute on function public.has_any_global_role(text[]) to authenticated;
grant execute on function public.is_platform_owner() to authenticated;
grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.is_platform_support() to authenticated;
grant execute on function public.is_platform_sales() to authenticated;
grant execute on function public.is_platform_operator() to authenticated;
grant execute on function public.can_manage_global_roles() to authenticated;

comment on function public.global_role_codes() is
  'Returns SaaS platform/global role codes for the current authenticated user.';

comment on function public.has_global_role(text) is
  'Returns true when the current authenticated user has the requested SaaS platform/global role.';

comment on function public.has_any_global_role(text[]) is
  'Returns true when the current authenticated user has any requested SaaS platform/global role.';

comment on function public.is_platform_operator() is
  'Returns true when the current authenticated user has any SaaS platform/global role.';

comment on function public.can_manage_global_roles() is
  'Temporary bootstrap helper allowing platform owners/admins and legacy sys_admin users to manage global role assignments.';

commit;
