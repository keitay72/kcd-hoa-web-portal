-- =========================================================
-- Migration: 0024_tenant_commercial_settings.sql
-- Purpose: Add SaaS tenant settings, billing, add-on, email, and SMS foundations
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.platform_tenants
  add column if not exists status text not null default 'active',
  add column if not exists updated_at timestamptz not null default now();

alter table public.platform_tenants
  drop constraint if exists platform_tenants_status_valid;

alter table public.platform_tenants
  add constraint platform_tenants_status_valid
  check (status in ('trialing', 'active', 'past_due', 'paused', 'cancelled'));

create table if not exists public.tenant_settings (
  tenant_id uuid primary key references public.platform_tenants(id) on delete cascade,
  support_email citext,
  support_phone text,
  logo_url text,
  primary_color text,
  secondary_color text,
  portal_hostname text unique,
  email_from_name text,
  email_reply_to citext,
  timezone text not null default 'America/Chicago',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_settings_support_email_valid check (support_email is null or support_email::text ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  constraint tenant_settings_email_reply_to_valid check (email_reply_to is null or email_reply_to::text ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  constraint tenant_settings_primary_color_valid check (primary_color is null or primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  constraint tenant_settings_secondary_color_valid check (secondary_color is null or secondary_color ~ '^#[0-9A-Fa-f]{6}$')
);

create table if not exists public.tenant_email_settings (
  tenant_id uuid primary key references public.platform_tenants(id) on delete cascade,
  provider text not null default 'platform_managed',
  sender_domain text,
  sender_email citext,
  reply_to_email citext,
  verification_status text not null default 'not_configured',
  provider_domain_id text,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_email_provider_valid check (provider in ('platform_managed', 'resend', 'postmark', 'sendgrid', 'custom_smtp')),
  constraint tenant_email_verification_status_valid check (verification_status in ('not_configured', 'pending', 'verified', 'failed', 'disabled')),
  constraint tenant_email_sender_email_valid check (sender_email is null or sender_email::text ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  constraint tenant_email_reply_to_email_valid check (reply_to_email is null or reply_to_email::text ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);

create table if not exists public.tenant_sms_settings (
  tenant_id uuid primary key references public.platform_tenants(id) on delete cascade,
  provider text not null default 'twilio',
  status text not null default 'disabled',
  twilio_subaccount_sid text,
  twilio_messaging_service_sid text,
  sending_phone_number text,
  monthly_message_limit integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_sms_provider_valid check (provider in ('twilio')),
  constraint tenant_sms_status_valid check (status in ('disabled', 'pending', 'active', 'suspended')),
  constraint tenant_sms_monthly_message_limit_positive check (monthly_message_limit is null or monthly_message_limit >= 0)
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text,
  status text not null default 'active',
  included_hoa_count integer,
  included_resident_count integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint subscription_plans_code_valid check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint subscription_plans_name_not_blank check (length(trim(name)) > 0),
  constraint subscription_plans_status_valid check (status in ('draft', 'active', 'archived')),
  constraint subscription_plans_included_hoa_count_positive check (included_hoa_count is null or included_hoa_count >= 0),
  constraint subscription_plans_included_resident_count_positive check (included_resident_count is null or included_resident_count >= 0)
);

create table if not exists public.subscription_plan_prices (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.subscription_plans(id) on delete cascade,
  billing_interval text not null,
  currency text not null default 'usd',
  unit_amount_cents integer not null,
  stripe_price_id text unique,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint subscription_plan_prices_interval_valid check (billing_interval in ('monthly', 'annual')),
  constraint subscription_plan_prices_currency_valid check (currency ~ '^[a-z]{3}$'),
  constraint subscription_plan_prices_unit_amount_positive check (unit_amount_cents >= 0),
  constraint subscription_plan_prices_status_valid check (status in ('active', 'archived'))
);

create table if not exists public.tenant_subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  price_id uuid references public.subscription_plan_prices(id) on delete set null,
  status text not null default 'trialing',
  stripe_customer_id text,
  stripe_subscription_id text unique,
  current_period_start timestamptz,
  current_period_end timestamptz,
  trial_ends_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_subscriptions_status_valid check (status in ('trialing', 'active', 'past_due', 'paused', 'cancelled', 'incomplete'))
);

create unique index if not exists uq_tenant_subscriptions_one_current
  on public.tenant_subscriptions(tenant_id)
  where status in ('trialing', 'active', 'past_due', 'paused', 'incomplete');

create table if not exists public.addon_catalog (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint addon_catalog_code_valid check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint addon_catalog_name_not_blank check (length(trim(name)) > 0),
  constraint addon_catalog_status_valid check (status in ('draft', 'active', 'archived'))
);

create table if not exists public.tenant_addons (
  tenant_id uuid not null references public.platform_tenants(id) on delete cascade,
  addon_id uuid not null references public.addon_catalog(id) on delete cascade,
  status text not null default 'enabled',
  stripe_subscription_item_id text,
  enabled_at timestamptz not null default now(),
  disabled_at timestamptz,
  configured_by uuid references public.profiles(id) on delete set null,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (tenant_id, addon_id),
  constraint tenant_addons_status_valid check (status in ('requested', 'enabled', 'disabled', 'suspended'))
);

create table if not exists public.tenant_billing_contacts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete cascade,
  name text not null,
  email citext not null,
  phone text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_billing_contacts_name_not_blank check (length(trim(name)) > 0),
  constraint tenant_billing_contacts_email_valid check (email::text ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);

create unique index if not exists uq_tenant_billing_contacts_one_primary
  on public.tenant_billing_contacts(tenant_id)
  where is_primary = true;

create index if not exists idx_platform_tenants_status
  on public.platform_tenants(status);

create index if not exists idx_tenant_subscriptions_tenant_status
  on public.tenant_subscriptions(tenant_id, status);

create index if not exists idx_tenant_addons_tenant_status
  on public.tenant_addons(tenant_id, status);

create index if not exists idx_tenant_billing_contacts_tenant
  on public.tenant_billing_contacts(tenant_id);

alter table public.tenant_settings enable row level security;
alter table public.tenant_email_settings enable row level security;
alter table public.tenant_sms_settings enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.subscription_plan_prices enable row level security;
alter table public.tenant_subscriptions enable row level security;
alter table public.addon_catalog enable row level security;
alter table public.tenant_addons enable row level security;
alter table public.tenant_billing_contacts enable row level security;

-- tenant_settings
drop policy if exists tenant_settings_select_scoped on public.tenant_settings;
create policy tenant_settings_select_scoped
on public.tenant_settings
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_settings_manage_scoped on public.tenant_settings;
create policy tenant_settings_manage_scoped
on public.tenant_settings
for all
to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

-- tenant_email_settings
drop policy if exists tenant_email_settings_select_scoped on public.tenant_email_settings;
create policy tenant_email_settings_select_scoped
on public.tenant_email_settings
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_email_settings_manage_scoped on public.tenant_email_settings;
create policy tenant_email_settings_manage_scoped
on public.tenant_email_settings
for all
to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

-- tenant_sms_settings
drop policy if exists tenant_sms_settings_select_scoped on public.tenant_sms_settings;
create policy tenant_sms_settings_select_scoped
on public.tenant_sms_settings
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_sms_settings_manage_scoped on public.tenant_sms_settings;
create policy tenant_sms_settings_manage_scoped
on public.tenant_sms_settings
for all
to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

-- subscription_plans and prices
drop policy if exists subscription_plans_select_authenticated on public.subscription_plans;
create policy subscription_plans_select_authenticated
on public.subscription_plans
for select
to authenticated
using (status = 'active' or public.is_platform_operator());

drop policy if exists subscription_plans_manage_platform_admin on public.subscription_plans;
create policy subscription_plans_manage_platform_admin
on public.subscription_plans
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin())
with check (public.is_platform_owner() or public.is_platform_admin());

drop policy if exists subscription_plan_prices_select_authenticated on public.subscription_plan_prices;
create policy subscription_plan_prices_select_authenticated
on public.subscription_plan_prices
for select
to authenticated
using (status = 'active' or public.is_platform_operator());

drop policy if exists subscription_plan_prices_manage_platform_admin on public.subscription_plan_prices;
create policy subscription_plan_prices_manage_platform_admin
on public.subscription_plan_prices
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin())
with check (public.is_platform_owner() or public.is_platform_admin());

-- tenant_subscriptions
drop policy if exists tenant_subscriptions_select_scoped on public.tenant_subscriptions;
create policy tenant_subscriptions_select_scoped
on public.tenant_subscriptions
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_subscriptions_manage_platform_commercial on public.tenant_subscriptions;
create policy tenant_subscriptions_manage_platform_commercial
on public.tenant_subscriptions
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin() or public.is_platform_sales())
with check (public.is_platform_owner() or public.is_platform_admin() or public.is_platform_sales());

-- addon_catalog and tenant_addons
drop policy if exists addon_catalog_select_authenticated on public.addon_catalog;
create policy addon_catalog_select_authenticated
on public.addon_catalog
for select
to authenticated
using (status = 'active' or public.is_platform_operator());

drop policy if exists addon_catalog_manage_platform_admin on public.addon_catalog;
create policy addon_catalog_manage_platform_admin
on public.addon_catalog
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin())
with check (public.is_platform_owner() or public.is_platform_admin());

drop policy if exists tenant_addons_select_scoped on public.tenant_addons;
create policy tenant_addons_select_scoped
on public.tenant_addons
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_addons_manage_scoped on public.tenant_addons;
create policy tenant_addons_manage_scoped
on public.tenant_addons
for all
to authenticated
using (public.can_manage_tenant(tenant_id) or public.is_platform_sales())
with check (public.can_manage_tenant(tenant_id) or public.is_platform_sales());

-- tenant_billing_contacts
drop policy if exists tenant_billing_contacts_select_scoped on public.tenant_billing_contacts;
create policy tenant_billing_contacts_select_scoped
on public.tenant_billing_contacts
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_billing_contacts_manage_scoped on public.tenant_billing_contacts;
create policy tenant_billing_contacts_manage_scoped
on public.tenant_billing_contacts
for all
to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

drop trigger if exists trg_platform_tenants_updated_at on public.platform_tenants;
create trigger trg_platform_tenants_updated_at
before update on public.platform_tenants
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_settings_updated_at on public.tenant_settings;
create trigger trg_tenant_settings_updated_at
before update on public.tenant_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_email_settings_updated_at on public.tenant_email_settings;
create trigger trg_tenant_email_settings_updated_at
before update on public.tenant_email_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_sms_settings_updated_at on public.tenant_sms_settings;
create trigger trg_tenant_sms_settings_updated_at
before update on public.tenant_sms_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_subscription_plans_updated_at on public.subscription_plans;
create trigger trg_subscription_plans_updated_at
before update on public.subscription_plans
for each row execute function public.set_updated_at();

drop trigger if exists trg_subscription_plan_prices_updated_at on public.subscription_plan_prices;
create trigger trg_subscription_plan_prices_updated_at
before update on public.subscription_plan_prices
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_subscriptions_updated_at on public.tenant_subscriptions;
create trigger trg_tenant_subscriptions_updated_at
before update on public.tenant_subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists trg_addon_catalog_updated_at on public.addon_catalog;
create trigger trg_addon_catalog_updated_at
before update on public.addon_catalog
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_addons_updated_at on public.tenant_addons;
create trigger trg_tenant_addons_updated_at
before update on public.tenant_addons
for each row execute function public.set_updated_at();

drop trigger if exists trg_tenant_billing_contacts_updated_at on public.tenant_billing_contacts;
create trigger trg_tenant_billing_contacts_updated_at
before update on public.tenant_billing_contacts
for each row execute function public.set_updated_at();

insert into public.tenant_settings (tenant_id, email_from_name, timezone)
select id, name, 'America/Chicago'
from public.platform_tenants
on conflict (tenant_id) do nothing;

insert into public.tenant_email_settings (tenant_id)
select id
from public.platform_tenants
on conflict (tenant_id) do nothing;

insert into public.tenant_sms_settings (tenant_id)
select id
from public.platform_tenants
on conflict (tenant_id) do nothing;

insert into public.addon_catalog (code, name, description, status)
values
  ('sms_notifications', 'SMS Notifications', 'Twilio-powered tenant SMS notification add-on.', 'active'),
  ('branded_email', 'Branded Email', 'Tenant-specific sender identity and email notification configuration.', 'active')
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  status = excluded.status,
  updated_at = now();

comment on table public.tenant_settings is
  'Tenant branding, support contact, hostname, and portal settings for subscribed waste-management companies.';

comment on table public.tenant_email_settings is
  'Tenant email sender configuration metadata. Do not store provider secrets here.';

comment on table public.tenant_sms_settings is
  'Tenant SMS add-on configuration metadata. Do not store Twilio auth tokens here.';

comment on table public.subscription_plans is
  'SaaS subscription plan catalog. Stripe should remain the payment source of truth.';

comment on table public.subscription_plan_prices is
  'Subscription plan pricing catalog mapped to Stripe prices when billing is enabled.';

comment on table public.tenant_subscriptions is
  'Tenant subscription state mirrored from Stripe for authorization and admin visibility.';

comment on table public.addon_catalog is
  'Optional SaaS add-on catalog, such as SMS notifications and branded email.';

comment on table public.tenant_addons is
  'Tenant enabled/requested add-ons and non-secret configuration.';

comment on table public.tenant_billing_contacts is
  'Tenant billing contacts for subscription and invoice communications.';

commit;
