-- Seed the SaaS subscription catalog for HOA Portal tenant subscriptions.
--
-- This migration intentionally does not modify existing tenant subscription or tenant
-- add-on assignments. It only upserts catalog plans, plan prices, and add-on entries.
--
-- Feature matrix and recommended feature flags:
--
-- Starter ($499 monthly / $4,990 annual)
--   Limits: 15 HOAs, 5,000 residents
--   Included features:
--     resident_portal
--     documents
--     announcements
--     service_schedules
--     tickets_basic
--     activation_codes
--     resident_verification
--   Recommended flags:
--     feature_resident_portal = true
--     feature_documents = true
--     feature_announcements = true
--     feature_service_schedules = true
--     feature_tickets_basic = true
--     feature_dispatch_dashboard = false
--     feature_advanced_ticket_management = false
--     feature_analytics_dashboard = false
--     feature_role_management = false
--     feature_custom_branding = false
--     feature_api_access = false
--
-- Professional ($1,499 monthly / $14,990 annual)
--   Limits: 75 HOAs, 25,000 residents
--   Included features:
--     everything in Starter
--     dispatch_dashboard
--     advanced_ticket_management
--     analytics_dashboard
--     role_management
--     custom_branding
--   Recommended flags:
--     feature_resident_portal = true
--     feature_documents = true
--     feature_announcements = true
--     feature_service_schedules = true
--     feature_tickets_basic = true
--     feature_dispatch_dashboard = true
--     feature_advanced_ticket_management = true
--     feature_analytics_dashboard = true
--     feature_role_management = true
--     feature_custom_branding = true
--     feature_api_access = false
--
-- Enterprise ($3,999 monthly / $39,990 annual)
--   Limits: unlimited HOAs, unlimited residents
--   Included features:
--     everything in Professional
--     api_access
--     custom_integrations
--     priority_support
--     dedicated_onboarding
--   Recommended flags:
--     feature_resident_portal = true
--     feature_documents = true
--     feature_announcements = true
--     feature_service_schedules = true
--     feature_tickets_basic = true
--     feature_dispatch_dashboard = true
--     feature_advanced_ticket_management = true
--     feature_analytics_dashboard = true
--     feature_role_management = true
--     feature_custom_branding = true
--     feature_api_access = true
--     feature_custom_integrations = true
--     feature_priority_support = true
--     feature_dedicated_onboarding = true
--
-- Existing schema convention for unlimited plan limits:
--   included_hoa_count = null
--   included_resident_count = null

insert into public.subscription_plans (
  code,
  name,
  description,
  status,
  included_hoa_count,
  included_resident_count
)
values
  (
    'starter',
    'Starter',
    'Starter plan for HOA Portal tenants. Includes up to 15 HOAs and 5,000 residents with resident portal, documents, announcements, service schedules, tickets, activation codes, and resident verification.',
    'active',
    15,
    5000
  ),
  (
    'professional',
    'Professional',
    'Professional plan for growing HOA Portal tenants. Includes up to 75 HOAs and 25,000 residents plus dispatch dashboard, advanced ticket management, analytics dashboard, role management, and custom branding.',
    'active',
    75,
    25000
  ),
  (
    'enterprise',
    'Enterprise',
    'Enterprise plan for large HOA Portal tenants. Includes unlimited HOAs, unlimited residents, API access, custom integrations, priority support, and dedicated onboarding.',
    'active',
    null,
    null
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  status = excluded.status,
  included_hoa_count = excluded.included_hoa_count,
  included_resident_count = excluded.included_resident_count,
  updated_at = now();

do $$
declare
  starter_plan_id uuid;
  professional_plan_id uuid;
  enterprise_plan_id uuid;
begin
  select id into starter_plan_id
  from public.subscription_plans
  where code = 'starter';

  select id into professional_plan_id
  from public.subscription_plans
  where code = 'professional';

  select id into enterprise_plan_id
  from public.subscription_plans
  where code = 'enterprise';

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = starter_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 49900,
      status = 'active',
      updated_at = now()
    where plan_id = starter_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (starter_plan_id, 'monthly', 'usd', 49900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = starter_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 499000,
      status = 'active',
      updated_at = now()
    where plan_id = starter_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (starter_plan_id, 'annual', 'usd', 499000, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = professional_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 149900,
      status = 'active',
      updated_at = now()
    where plan_id = professional_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (professional_plan_id, 'monthly', 'usd', 149900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = professional_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 1499000,
      status = 'active',
      updated_at = now()
    where plan_id = professional_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (professional_plan_id, 'annual', 'usd', 1499000, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = enterprise_plan_id
      and billing_interval = 'monthly'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 399900,
      status = 'active',
      updated_at = now()
    where plan_id = enterprise_plan_id
      and billing_interval = 'monthly';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (enterprise_plan_id, 'monthly', 'usd', 399900, 'active');
  end if;

  if exists (
    select 1
    from public.subscription_plan_prices
    where plan_id = enterprise_plan_id
      and billing_interval = 'annual'
  ) then
    update public.subscription_plan_prices
    set
      currency = 'usd',
      unit_amount_cents = 3999000,
      status = 'active',
      updated_at = now()
    where plan_id = enterprise_plan_id
      and billing_interval = 'annual';
  else
    insert into public.subscription_plan_prices (
      plan_id,
      billing_interval,
      currency,
      unit_amount_cents,
      status
    )
    values (enterprise_plan_id, 'annual', 'usd', 3999000, 'active');
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
    'sms_notifications',
    'SMS Notifications',
    'Twilio-powered tenant SMS notification add-on. Price: $49/month.',
    'active'
  ),
  (
    'white_label_branding',
    'White Label Branding',
    'Tenant white-label branding add-on. Price: $299/month.',
    'active'
  ),
  (
    'custom_domain',
    'Custom Domain',
    'Tenant custom portal domain add-on. Price: $99/month.',
    'active'
  ),
  (
    'advertising_platform',
    'Advertising Platform',
    'HOA and resident advertising platform add-on. Price: $99/month.',
    'active'
  ),
  (
    'api_access',
    'API Access',
    'Tenant API access. Included with Enterprise plan.',
    'active'
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  status = excluded.status,
  updated_at = now();
