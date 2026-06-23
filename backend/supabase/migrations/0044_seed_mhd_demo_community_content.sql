-- =========================================================
-- Migration: 0044_seed_mhd_demo_community_content.sql
-- Purpose: Add local demo content for Mountain High Disposal resident portal testing
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

with mhd_context as (
  select
    hc.id as hoa_id,
    ca.id as customer_account_id,
    owner_profile.id as owner_user_id,
    community_role.id as community_role_id
  from public.platform_tenants tenant
  join public.hoa_communities hc
    on hc.tenant_id = tenant.id
  join public.customer_accounts ca
    on ca.tenant_id = tenant.id
   and ca.account_type = 'community'
   and (
     ca.external_account_ref = hc.id::text
     or ca.metadata ->> 'legacy_hoa_id' = hc.id::text
   )
  left join public.profiles owner_profile
    on owner_profile.email = 'mhd-owner@example.com'
  left join public.roles community_role
    on community_role.code = 'community_admin'
  where tenant.code = 'MOUNTAIN_HIGH_DISPOSAL'
    and hc.name = 'The Hills of Budweiser'
  limit 1
)
insert into public.announcements (
  id,
  hoa_id,
  title,
  body,
  publish_at,
  expire_at,
  status,
  created_by
)
select
  'b8000000-0000-4000-8000-000000000001'::uuid,
  hoa_id,
  'Holiday service reminder',
  'Mountain High Disposal will shift pickup by one day during observed holiday weeks. Please place carts out by 7:00 AM.',
  now() - interval '1 hour',
  now() + interval '90 days',
  'published',
  owner_user_id
from mhd_context
on conflict (id) do update
set
  hoa_id = excluded.hoa_id,
  title = excluded.title,
  body = excluded.body,
  publish_at = excluded.publish_at,
  expire_at = excluded.expire_at,
  status = excluded.status,
  created_by = excluded.created_by,
  updated_at = now();

with mhd_context as (
  select
    hc.id as hoa_id,
    owner_profile.id as owner_user_id
  from public.platform_tenants tenant
  join public.hoa_communities hc
    on hc.tenant_id = tenant.id
  left join public.profiles owner_profile
    on owner_profile.email = 'mhd-owner@example.com'
  where tenant.code = 'MOUNTAIN_HIGH_DISPOSAL'
    and hc.name = 'The Hills of Budweiser'
  limit 1
)
insert into public.documents (
  id,
  hoa_id,
  title,
  category,
  storage_path,
  mime_type,
  file_size,
  visibility_scope,
  status,
  created_by
)
select
  'b8000000-0000-4000-8000-000000000002'::uuid,
  hoa_id,
  'The Hills of Budweiser Service Guide',
  'service',
  hoa_id::text || '/service-guide.pdf',
  'application/pdf',
  0,
  'resident',
  'active',
  owner_user_id
from mhd_context
on conflict (id) do update
set
  hoa_id = excluded.hoa_id,
  title = excluded.title,
  category = excluded.category,
  storage_path = excluded.storage_path,
  mime_type = excluded.mime_type,
  file_size = excluded.file_size,
  visibility_scope = excluded.visibility_scope,
  status = excluded.status,
  created_by = excluded.created_by,
  updated_at = now();

with mhd_context as (
  select hc.id as hoa_id
  from public.platform_tenants tenant
  join public.hoa_communities hc
    on hc.tenant_id = tenant.id
  where tenant.code = 'MOUNTAIN_HIGH_DISPOSAL'
    and hc.name = 'The Hills of Budweiser'
  limit 1
)
insert into public.service_schedules (
  id,
  hoa_id,
  address_id,
  service_type,
  service_day,
  effective_date,
  end_date,
  notes,
  schedule_rule,
  route_name,
  status
)
select
  schedule.id,
  mhd_context.hoa_id,
  null,
  schedule.service_type,
  schedule.service_day,
  current_date,
  null,
  schedule.notes,
  schedule.schedule_rule,
  schedule.route_name,
  'active'
from mhd_context
cross join (
  values
    (
      'b8000000-0000-4000-8000-000000000003'::uuid,
      'trash',
      2::smallint,
      'The Hills of Budweiser community-wide weekly trash pickup',
      'Every Tuesday',
      'MHD Hills Trash'
    ),
    (
      'b8000000-0000-4000-8000-000000000004'::uuid,
      'recycling',
      5::smallint,
      'The Hills of Budweiser community-wide recycling pickup',
      'Every Friday',
      'MHD Hills Recycling'
    )
) as schedule(id, service_type, service_day, notes, schedule_rule, route_name)
on conflict (id) do update
set
  hoa_id = excluded.hoa_id,
  address_id = excluded.address_id,
  service_type = excluded.service_type,
  service_day = excluded.service_day,
  effective_date = excluded.effective_date,
  end_date = excluded.end_date,
  notes = excluded.notes,
  schedule_rule = excluded.schedule_rule,
  route_name = excluded.route_name,
  status = excluded.status,
  updated_at = now();

with mhd_context as (
  select
    ca.id as customer_account_id,
    owner_profile.id as owner_user_id,
    community_role.id as community_role_id
  from public.platform_tenants tenant
  join public.hoa_communities hc
    on hc.tenant_id = tenant.id
  join public.customer_accounts ca
    on ca.tenant_id = tenant.id
   and ca.account_type = 'community'
   and (
     ca.external_account_ref = hc.id::text
     or ca.metadata ->> 'legacy_hoa_id' = hc.id::text
   )
  join public.profiles owner_profile
    on owner_profile.email = 'mhd-owner@example.com'
  join public.roles community_role
    on community_role.code = 'community_admin'
  where tenant.code = 'MOUNTAIN_HIGH_DISPOSAL'
    and hc.name = 'The Hills of Budweiser'
  limit 1
)
insert into public.customer_memberships (
  tenant_id,
  user_id,
  customer_account_id,
  service_location_id,
  role_id,
  status,
  is_primary_contact,
  created_by
)
select
  ca.tenant_id,
  mhd_context.owner_user_id,
  mhd_context.customer_account_id,
  null,
  mhd_context.community_role_id,
  'active',
  true,
  mhd_context.owner_user_id
from mhd_context
join public.customer_accounts ca
  on ca.id = mhd_context.customer_account_id
where not exists (
  select 1
  from public.customer_memberships existing
  where existing.customer_account_id = mhd_context.customer_account_id
    and existing.user_id = mhd_context.owner_user_id
    and existing.role_id = mhd_context.community_role_id
    and existing.service_location_id is null
);

commit;
