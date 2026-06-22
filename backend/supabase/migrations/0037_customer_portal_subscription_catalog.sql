-- =========================================================
-- Migration: 0037_customer_portal_subscription_catalog.sql
-- Purpose: Seed capacity-based customer portal subscription plans
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- Archive the old HOA feature-gated plans without deleting them. Existing tenant
-- subscriptions can still reference historical plans; new assignments should use
-- the customer portal capacity plans below.
update public.subscription_plans
set
  status = 'archived',
  updated_at = now()
where code in ('starter', 'professional');

update public.subscription_plan_prices spp
set
  status = 'archived',
  updated_at = now()
from public.subscription_plans sp
where spp.plan_id = sp.id
  and sp.code in ('starter', 'professional');

insert into public.subscription_plans (
  code,
  name,
  description,
  status,
  included_hoa_count,
  included_resident_count,
  included_service_location_count,
  service_location_overage_cents,
  service_location_grace_percent
)
values
  (
    'local',
    'Local',
    'Customer Portal Local plan. Includes all core portal features for up to 10,000 active service locations.',
    'active',
    null,
    null,
    10000,
    8,
    5
  ),
  (
    'regional',
    'Regional',
    'Customer Portal Regional plan. Includes all core portal features for up to 30,000 active service locations.',
    'active',
    null,
    null,
    30000,
    6,
    5
  ),
  (
    'metro',
    'Metro',
    'Customer Portal Metro plan. Includes all core portal features for up to 75,000 active service locations.',
    'active',
    null,
    null,
    75000,
    4,
    5
  ),
  (
    'enterprise',
    'Enterprise',
    'Customer Portal Enterprise plan. Includes all core portal features with custom capacity, onboarding, support, and pricing.',
    'active',
    null,
    null,
    null,
    null,
    5
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  status = excluded.status,
  included_hoa_count = excluded.included_hoa_count,
  included_resident_count = excluded.included_resident_count,
  included_service_location_count = excluded.included_service_location_count,
  service_location_overage_cents = excluded.service_location_overage_cents,
  service_location_grace_percent = excluded.service_location_grace_percent,
  updated_at = now();

do $$
declare
  local_plan_id uuid;
  regional_plan_id uuid;
  metro_plan_id uuid;
begin
  select id into local_plan_id
  from public.subscription_plans
  where code = 'local';

  select id into regional_plan_id
  from public.subscription_plans
  where code = 'regional';

  select id into metro_plan_id
  from public.subscription_plans
  where code = 'metro';

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = local_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 79900,
      status = 'active',
      updated_at = now()
    where plan_id = local_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (local_plan_id, 'monthly', 'usd', 79900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = local_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 799000,
      status = 'active',
      updated_at = now()
    where plan_id = local_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (local_plan_id, 'annual', 'usd', 799000, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = regional_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 149900,
      status = 'active',
      updated_at = now()
    where plan_id = regional_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (regional_plan_id, 'monthly', 'usd', 149900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = regional_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 1499000,
      status = 'active',
      updated_at = now()
    where plan_id = regional_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (regional_plan_id, 'annual', 'usd', 1499000, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = metro_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 249900,
      status = 'active',
      updated_at = now()
    where plan_id = metro_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (metro_plan_id, 'monthly', 'usd', 249900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = metro_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 2499000,
      status = 'active',
      updated_at = now()
    where plan_id = metro_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (metro_plan_id, 'annual', 'usd', 2499000, 'active');
  end if;
end $$;

insert into public.addon_catalog (
  code,
  name,
  description,
  status
)
values
  (
    'custom_email_domain',
    'Custom Email Domain',
    'Tenant-specific sending domain for branded portal emails.',
    'active'
  ),
  (
    'advanced_integrations',
    'Advanced Integrations',
    'Advanced API and integration support for enterprise tenant workflows.',
    'active'
  ),
  (
    'white_glove_onboarding',
    'White-Glove Onboarding',
    'One-time or managed onboarding support for data import, cleanup, and tenant launch.',
    'active'
  ),
  (
    'premium_support',
    'Premium Support',
    'Premium support and SLA add-on for larger tenants.',
    'active'
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  status = excluded.status,
  updated_at = now();

update public.addon_catalog
set
  description = 'SMS messaging add-on for tenant customer notifications. Pricing should include base fee plus usage.',
  status = 'active',
  updated_at = now()
where code = 'sms_notifications';

-- Branding and custom domain are core customer portal capabilities in the new
-- model, not paid feature gates.
update public.addon_catalog
set
  status = 'archived',
  updated_at = now()
where code in ('white_label_branding', 'custom_domain', 'advertising_platform', 'api_access');

commit;
