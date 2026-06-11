-- Track whether invited admin users completed first-password setup.

alter table public.profiles
  add column if not exists password_set_at timestamptz;

-- Existing active users who were not created through the admin invite lifecycle
-- already have usable passwords. Backfill them so they are not forced through
-- first-password setup.
update public.profiles profile
set password_set_at = coalesce(profile.password_set_at, profile.created_at, now())
where profile.password_set_at is null
  and profile.status = 'active'
  and not exists (
    select 1
    from public.admin_user_invites invite
    where invite.user_id = profile.id
      and invite.status in ('pending', 'accepted', 'expired', 'failed')
  );

comment on column public.profiles.password_set_at is
  'Timestamp when the user completed first-password setup or had an existing password before invite tracking.';
