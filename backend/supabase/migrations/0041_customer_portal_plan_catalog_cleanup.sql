-- =========================================================
-- Migration: 0041_customer_portal_plan_catalog_cleanup.sql
-- Purpose: Finalize customer-portal subscription tiers and retire legacy HOA tiers
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.subscription_plans
  add column if not exists included_service_location_count integer,
  add column if not exists service_location_overage_cents integer,
  add column if not exists service_location_grace_percent integer not null default 5;

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
    'Customer portal subscription for small haulers. Includes every core feature for up to 10,000 active customer service locations.',
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
    'Customer portal subscription for growing regional haulers. Includes every core feature for up to 30,000 active customer service locations.',
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
    'Customer portal subscription for large market operators. Includes every core feature for up to 75,000 active customer service locations.',
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
    'Custom customer portal subscription for haulers that need higher capacity, onboarding support, and negotiated pricing.',
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
  enterprise_plan_id uuid;
  price_row record;
begin
  select id into local_plan_id from public.subscription_plans where code = 'local';
  select id into regional_plan_id from public.subscription_plans where code = 'regional';
  select id into metro_plan_id from public.subscription_plans where code = 'metro';
  select id into enterprise_plan_id from public.subscription_plans where code = 'enterprise';

  for price_row in
    select *
    from (
      values
        (local_plan_id, 'monthly', 'usd', 79900, 'active'),
        (local_plan_id, 'annual', 'usd', 799000, 'active'),
        (regional_plan_id, 'monthly', 'usd', 149900, 'active'),
        (regional_plan_id, 'annual', 'usd', 1499000, 'active'),
        (metro_plan_id, 'monthly', 'usd', 249900, 'active'),
        (metro_plan_id, 'annual', 'usd', 2499000, 'active')
    ) as prices(plan_id, billing_interval, currency, unit_amount_cents, status)
  loop
    if exists (
      select 1
      from public.subscription_plan_prices
      where plan_id = price_row.plan_id
        and billing_interval = price_row.billing_interval
    ) then
      update public.subscription_plan_prices
      set
        currency = price_row.currency,
        unit_amount_cents = price_row.unit_amount_cents,
        status = price_row.status,
        updated_at = now()
      where plan_id = price_row.plan_id
        and billing_interval = price_row.billing_interval;
    else
      insert into public.subscription_plan_prices (
        plan_id,
        billing_interval,
        currency,
        unit_amount_cents,
        status
      )
      values (
        price_row.plan_id,
        price_row.billing_interval,
        price_row.currency,
        price_row.unit_amount_cents,
        price_row.status
      );
    end if;
  end loop;

  update public.subscription_plan_prices
  set
    status = 'archived',
    updated_at = now()
  where plan_id = enterprise_plan_id;
end $$;

commit;
