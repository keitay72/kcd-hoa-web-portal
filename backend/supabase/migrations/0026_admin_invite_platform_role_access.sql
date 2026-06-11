-- =========================================================
-- Migration: 0026_admin_invite_platform_role_access.sql
-- Purpose: Allow canonical platform admins to manage admin invite lifecycle
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create or replace function public.can_manage_admin_invites()
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

revoke all on function public.can_manage_admin_invites() from public, anon, authenticated;
grant execute on function public.can_manage_admin_invites() to authenticated;

drop policy if exists admin_user_invites_select_sys_admin on public.admin_user_invites;
drop policy if exists admin_user_invites_manage_sys_admin on public.admin_user_invites;
drop policy if exists admin_user_invites_select_platform_admin on public.admin_user_invites;
drop policy if exists admin_user_invites_manage_platform_admin on public.admin_user_invites;

create policy admin_user_invites_select_platform_admin
on public.admin_user_invites
for select
to authenticated
using (public.can_manage_admin_invites());

create policy admin_user_invites_manage_platform_admin
on public.admin_user_invites
for all
to authenticated
using (public.can_manage_admin_invites())
with check (public.can_manage_admin_invites());

create or replace function public.sync_admin_invite_acceptances()
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  changed_count integer;
begin
  if not public.can_manage_admin_invites() then
    raise exception 'Only platform administrators may sync admin invite acceptances';
  end if;

  update public.admin_user_invites invite
  set status = 'accepted',
      accepted_at = coalesce(auth_user.last_sign_in_at, auth_user.email_confirmed_at, now())
  from auth.users auth_user
  where invite.user_id = auth_user.id
    and invite.status = 'pending'
    and (
      auth_user.last_sign_in_at is not null
      or auth_user.email_confirmed_at is not null
    );

  get diagnostics changed_count = row_count;

  update public.profiles profile
  set status = 'active'
  from public.admin_user_invites invite
  where invite.user_id = profile.id
    and invite.status = 'accepted'
    and profile.status = 'invite_pending';

  update public.admin_user_invites
  set status = 'expired',
      failure_message = coalesce(failure_message, 'Invite expired before acceptance')
  where status = 'pending'
    and expires_at < now();

  update public.profiles profile
  set status = 'invite_expired'
  from public.admin_user_invites invite
  where invite.user_id = profile.id
    and invite.status = 'expired'
    and profile.status = 'invite_pending';

  return changed_count;
end;
$$;

revoke all on function public.sync_admin_invite_acceptances() from public, anon, authenticated;
grant execute on function public.sync_admin_invite_acceptances() to authenticated;

comment on function public.can_manage_admin_invites() is
  'Returns true for canonical SaaS platform admins/owners and legacy sys_admin users allowed to manage admin invite lifecycle records.';

comment on function public.sync_admin_invite_acceptances() is
  'Platform-admin callable helper that syncs invite/profile status from Supabase Auth confirmation or sign-in state.';

commit;
