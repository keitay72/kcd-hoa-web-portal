-- =========================================================
-- Migration: 0015_admin_user_invite_lifecycle.sql
-- Purpose: Track admin user invite lifecycle for pending/resend/cancel UX
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.profiles
  drop constraint if exists profiles_status_valid;

alter table public.profiles
  add constraint profiles_status_valid
  check (status in ('active', 'disabled', 'invite_pending', 'invite_expired'));

create table if not exists public.admin_user_invites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  email citext not null,
  first_name text not null,
  middle_name text,
  last_name text not null,
  phone text,
  role_id bigint not null references public.roles(id) on delete restrict,
  role_code text not null,
  tenant_id uuid references public.platform_tenants(id) on delete restrict,
  hoa_id uuid references public.hoa_communities(id) on delete restrict,
  status text not null default 'pending',
  invited_by uuid references public.profiles(id) on delete set null,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  expires_at timestamptz not null default (now() + interval '7 days'),
  resent_at timestamptz,
  resend_count integer not null default 0,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles(id) on delete set null,
  failure_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint admin_user_invites_status_valid check (
    status in ('pending', 'accepted', 'expired', 'cancelled', 'failed')
  ),
  constraint admin_user_invites_first_name_valid check (length(trim(first_name)) > 0),
  constraint admin_user_invites_last_name_valid check (length(trim(last_name)) > 0),
  constraint admin_user_invites_email_valid check (length(trim(email::text)) > 0),
  constraint admin_user_invites_phone_digits check (phone is null or phone ~ '^[0-9]{10}$'),
  constraint admin_user_invites_scope_valid check (
    (tenant_id is not null and hoa_id is null)
    or (tenant_id is null and hoa_id is not null)
  ),
  constraint admin_user_invites_cancelled_fields_valid check (
    (status = 'cancelled' and cancelled_at is not null)
    or (status <> 'cancelled')
  ),
  constraint admin_user_invites_accepted_fields_valid check (
    (status = 'accepted' and accepted_at is not null)
    or (status <> 'accepted')
  )
);

create unique index if not exists uq_admin_user_invites_one_pending_email
  on public.admin_user_invites(lower(email::text))
  where status = 'pending';

create index if not exists idx_admin_user_invites_user_id
  on public.admin_user_invites(user_id);

create index if not exists idx_admin_user_invites_email
  on public.admin_user_invites(email);

create index if not exists idx_admin_user_invites_status
  on public.admin_user_invites(status);

create index if not exists idx_admin_user_invites_hoa_id
  on public.admin_user_invites(hoa_id);

create index if not exists idx_admin_user_invites_tenant_id
  on public.admin_user_invites(tenant_id);

drop trigger if exists trg_admin_user_invites_updated_at on public.admin_user_invites;
create trigger trg_admin_user_invites_updated_at
before update on public.admin_user_invites
for each row execute function public.set_updated_at();

alter table public.admin_user_invites enable row level security;

drop policy if exists admin_user_invites_select_sys_admin on public.admin_user_invites;
create policy admin_user_invites_select_sys_admin
on public.admin_user_invites
for select
to authenticated
using (public.is_sys_admin());

drop policy if exists admin_user_invites_manage_sys_admin on public.admin_user_invites;
create policy admin_user_invites_manage_sys_admin
on public.admin_user_invites
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

create or replace function public.sync_admin_invite_acceptances()
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  changed_count integer;
begin
  if not public.is_sys_admin() then
    raise exception 'Only sys_admin users may sync admin invite acceptances';
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

comment on table public.admin_user_invites is
  'Lifecycle tracking for Admin Web App user invitations, including pending, resend, cancellation, acceptance, and failure states.';

comment on function public.sync_admin_invite_acceptances() is
  'Sys-admin callable helper that syncs invite/profile status from Supabase Auth confirmation or sign-in state.';

commit;
