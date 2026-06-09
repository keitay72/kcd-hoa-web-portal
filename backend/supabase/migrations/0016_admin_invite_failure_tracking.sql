-- =========================================================
-- Migration: 0016_admin_invite_failure_tracking.sql
-- Purpose: Track failed admin invite delivery attempts for retry UX
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.admin_user_invites
  add column if not exists failure_reason text,
  add column if not exists failure_timestamp timestamptz;

update public.admin_user_invites
set failure_reason = coalesce(failure_reason, failure_message),
    failure_timestamp = coalesce(failure_timestamp, updated_at)
where status = 'failed'
  and (failure_reason is null or failure_timestamp is null);

alter table public.admin_user_invites
  drop constraint if exists admin_user_invites_failed_fields_valid,
  add constraint admin_user_invites_failed_fields_valid check (
    (status = 'failed' and failure_reason is not null and failure_timestamp is not null)
    or (status <> 'failed')
  );

comment on column public.admin_user_invites.failure_reason is
  'Human-readable reason the invite email could not be generated or delivered by the auth provider.';

comment on column public.admin_user_invites.failure_timestamp is
  'Timestamp when the latest invite failure occurred.';

commit;
