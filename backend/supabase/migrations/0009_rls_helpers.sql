-- =========================================================
-- Migration: 0009_rls_helpers.sql
-- Purpose: Create helper functions used by Phase 1 RLS policies
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create or replace function public.auth_role_codes()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(array_agg(distinct r.code), '{}')::text[]
  from public.user_platform_roles upr
  join public.roles r on r.id = upr.role_id
  where upr.user_id = auth.uid();
$$;

create or replace function public.has_platform_role(_role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select _role = any(public.auth_role_codes());
$$;

create or replace function public.has_any_platform_role(_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from unnest(public.auth_role_codes()) role_code
    where role_code = any(_roles)
  );
$$;

create or replace function public.is_sys_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_platform_role('sys_admin');
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

create or replace function public.user_in_hoa(_hoa_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_hoa_memberships m
    where m.user_id = auth.uid()
      and m.hoa_id = _hoa_id
      and m.status = 'active'
  );
$$;

create or replace function public.user_has_hoa_role(_hoa_id uuid, _roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_hoa_memberships m
    join public.roles r on r.id = m.role_id
    where m.user_id = auth.uid()
      and m.hoa_id = _hoa_id
      and m.status = 'active'
      and r.code = any(_roles)
  );
$$;

create or replace function public.user_has_current_address_membership(
  _user_id uuid,
  _hoa_id uuid,
  _address_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_address_memberships uam
    where uam.user_id = _user_id
      and uam.hoa_id = _hoa_id
      and (_address_id is null or uam.address_id = _address_id)
      and uam.is_current = true
  );
$$;

create or replace function public.can_read_ticket(_ticket_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tickets t
    where t.id = _ticket_id
      and (
        t.requester_user_id = auth.uid()
        or public.user_has_hoa_role(t.hoa_id, array['hoa_board', 'hoa_manager'])
        or public.is_kcd_staff()
      )
  );
$$;

create or replace function public.storage_folder_name(_object_name text, _position int)
returns text
language sql
immutable
as $$
  select nullif(split_part(_object_name, '/', _position), '');
$$;

create or replace function public.storage_folder_uuid(_object_name text, _position int)
returns uuid
language plpgsql
immutable
as $$
declare
  folder_value text;
begin
  folder_value := public.storage_folder_name(_object_name, _position);

  if folder_value is null then
    return null;
  end if;

  return folder_value::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

-- SECURITY DEFINER functions should not inherit PostgreSQL's default PUBLIC
-- execute privilege. Grant only the roles that need them for app queries/RLS.
revoke all on function public.auth_role_codes() from public, anon, authenticated;
revoke all on function public.has_platform_role(text) from public, anon, authenticated;
revoke all on function public.has_any_platform_role(text[]) from public, anon, authenticated;
revoke all on function public.is_sys_admin() from public, anon, authenticated;
revoke all on function public.is_kcd_staff() from public, anon, authenticated;
revoke all on function public.user_in_hoa(uuid) from public, anon, authenticated;
revoke all on function public.user_has_hoa_role(uuid, text[]) from public, anon, authenticated;
revoke all on function public.user_has_current_address_membership(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.can_read_ticket(uuid) from public, anon, authenticated;

grant execute on function public.is_sys_admin() to authenticated;
grant execute on function public.is_kcd_staff() to authenticated;
grant execute on function public.user_in_hoa(uuid) to authenticated;
grant execute on function public.user_has_hoa_role(uuid, text[]) to authenticated;
grant execute on function public.user_has_current_address_membership(uuid, uuid, uuid) to authenticated;
grant execute on function public.can_read_ticket(uuid) to authenticated;

commit;
