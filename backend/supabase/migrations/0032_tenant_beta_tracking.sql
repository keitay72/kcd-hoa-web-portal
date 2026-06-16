-- 0032_tenant_beta_tracking.sql
-- Adds lightweight beta coordination fields to the tenant onboarding record.

alter table public.tenant_onboarding_status
  add column if not exists beta_status text not null default 'not_started';

alter table public.tenant_onboarding_status
  add column if not exists beta_contact_name text;

alter table public.tenant_onboarding_status
  add column if not exists beta_contact_email text;

alter table public.tenant_onboarding_status
  add column if not exists beta_target_launch_date date;

alter table public.tenant_onboarding_status
  add column if not exists hoa_data_status text not null default 'not_requested';

alter table public.tenant_onboarding_status
  add column if not exists known_issues text;

alter table public.tenant_onboarding_status
  add column if not exists ready_for_hoa_onboarding boolean not null default false;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tenant_onboarding_beta_status_valid'
      and conrelid = 'public.tenant_onboarding_status'::regclass
  ) then
    alter table public.tenant_onboarding_status
      add constraint tenant_onboarding_beta_status_valid
      check (beta_status in (
        'not_started',
        'agreement_pending',
        'configuring',
        'tenant_review',
        'active_beta',
        'paused',
        'completed'
      ));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'tenant_onboarding_hoa_data_status_valid'
      and conrelid = 'public.tenant_onboarding_status'::regclass
  ) then
    alter table public.tenant_onboarding_status
      add constraint tenant_onboarding_hoa_data_status_valid
      check (hoa_data_status in (
        'not_requested',
        'requested',
        'received',
        'importing',
        'imported',
        'needs_cleanup'
      ));
  end if;
end $$;

create index if not exists idx_tenant_onboarding_beta_status
  on public.tenant_onboarding_status(beta_status);

create index if not exists idx_tenant_onboarding_hoa_data_status
  on public.tenant_onboarding_status(hoa_data_status);

comment on column public.tenant_onboarding_status.beta_status is
  'Internal beta lifecycle state for no-cost tenant pilots.';

comment on column public.tenant_onboarding_status.beta_contact_name is
  'Primary tenant-side contact for beta coordination.';

comment on column public.tenant_onboarding_status.beta_contact_email is
  'Primary tenant-side contact email for beta coordination.';

comment on column public.tenant_onboarding_status.beta_target_launch_date is
  'Internal target date for tenant beta handoff or HOA onboarding.';

comment on column public.tenant_onboarding_status.hoa_data_status is
  'Tracks whether the tenant HOA/address data has been requested, received, imported, or needs cleanup.';

comment on column public.tenant_onboarding_status.known_issues is
  'Internal tenant-specific beta issues, caveats, or follow-up notes.';

comment on column public.tenant_onboarding_status.ready_for_hoa_onboarding is
  'True when the tenant is ready to begin HOA/user onboarding during beta.';
