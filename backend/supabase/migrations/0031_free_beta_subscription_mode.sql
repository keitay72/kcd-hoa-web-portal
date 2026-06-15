-- 0031_free_beta_subscription_mode.sql
-- Adds a non-billable beta mode for tenant subscriptions while preserving
-- real plan assignment, feature gates, usage limits, and overage warnings.

alter table public.tenant_subscriptions
  add column if not exists billing_mode text not null default 'manual';

alter table public.tenant_subscriptions
  add column if not exists free_beta_ends_at timestamptz;

alter table public.tenant_subscriptions
  add column if not exists billing_notes text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tenant_subscriptions_billing_mode_valid'
      and conrelid = 'public.tenant_subscriptions'::regclass
  ) then
    alter table public.tenant_subscriptions
      add constraint tenant_subscriptions_billing_mode_valid
      check (billing_mode in ('manual', 'stripe', 'free_beta'));
  end if;
end $$;

create index if not exists idx_tenant_subscriptions_billing_mode
  on public.tenant_subscriptions(billing_mode, status);

comment on column public.tenant_subscriptions.billing_mode is
  'Controls how a tenant subscription is fulfilled: manual, stripe, or free_beta.';

comment on column public.tenant_subscriptions.free_beta_ends_at is
  'Optional planned end date for free beta access. Plan limits and entitlements still apply.';

comment on column public.tenant_subscriptions.billing_notes is
  'Internal billing notes for beta, manual billing, Stripe setup, or migration context.';
