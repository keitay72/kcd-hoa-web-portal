-- Allow an invited user to mark only their own admin invite accepted after
-- Supabase Auth verifies the invite link and creates an authenticated session.

create or replace function public.mark_current_user_admin_invite_accepted()
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  changed_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to accept an invite';
  end if;

  update public.admin_user_invites invite
  set status = 'accepted',
      accepted_at = coalesce(auth_user.last_sign_in_at, auth_user.email_confirmed_at, now())
  from auth.users auth_user
  where invite.user_id = auth.uid()
    and auth_user.id = invite.user_id
    and invite.status in ('pending', 'failed', 'expired')
    and (
      auth_user.last_sign_in_at is not null
      or auth_user.email_confirmed_at is not null
    );

  get diagnostics changed_count = row_count;

  update public.profiles profile
  set status = 'active',
      updated_at = now()
  where profile.id = auth.uid()
    and profile.status in ('invite_pending', 'invite_expired', 'disabled')
    and exists (
      select 1
      from public.admin_user_invites invite
      where invite.user_id = profile.id
        and invite.status = 'accepted'
    );

  return changed_count;
end;
$$;

revoke all on function public.mark_current_user_admin_invite_accepted() from public, anon, authenticated;
grant execute on function public.mark_current_user_admin_invite_accepted() to authenticated;

comment on function public.mark_current_user_admin_invite_accepted() is
  'Marks the current authenticated user own admin invite accepted after invite verification.';
