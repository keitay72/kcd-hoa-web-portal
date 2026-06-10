-- =========================================================
-- Migration: 0025_tenant_onboarding_status.sql
-- Purpose: Track SaaS tenant onboarding workflow state
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.tenant_onboarding_status (
  tenant_id uuid primary key references public.platform_tenants(id) on delete cascade,
  status text not null default 'not_started',
  owner_user_id uuid references public.profiles(id) on delete set null,
  kickoff_completed_at timestamptz,
  launch_ready_at timestamptz,
  launched_at timestamptz,
  blocked_reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null,

  constraint tenant_onboarding_status_valid check (
    status in ('not_started', 'in_progress', 'blocked', 'ready_to_launch', 'launched', 'cancelled')
  )
);

create index if not exists idx_tenant_onboarding_status_status
  on public.tenant_onboarding_status(status);

alter table public.tenant_onboarding_status enable row level security;

drop policy if exists tenant_onboarding_status_select_scoped on public.tenant_onboarding_status;
create policy tenant_onboarding_status_select_scoped
on public.tenant_onboarding_status
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_onboarding_status_manage_scoped on public.tenant_onboarding_status;
create policy tenant_onboarding_status_manage_scoped
on public.tenant_onboarding_status
for all
to authenticated
using (
  public.can_manage_tenant(tenant_id)
  or public.is_platform_sales()
)
with check (
  public.can_manage_tenant(tenant_id)
  or public.is_platform_sales()
);

drop trigger if exists trg_tenant_onboarding_status_updated_at on public.tenant_onboarding_status;
create trigger trg_tenant_onboarding_status_updated_at
before update on public.tenant_onboarding_status
for each row execute function public.set_updated_at();

insert into public.tenant_onboarding_status (tenant_id, status)
select id, 'not_started'
from public.platform_tenants
on conflict (tenant_id) do nothing;

comment on table public.tenant_onboarding_status is
  'Tracks SaaS tenant onboarding workflow status, notes, blockers, and launch readiness.';

comment on column public.tenant_onboarding_status.status is
  'Tenant onboarding lifecycle state: not_started, in_progress, blocked, ready_to_launch, launched, or cancelled.';

commit;
