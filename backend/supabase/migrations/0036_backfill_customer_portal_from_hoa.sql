-- =========================================================
-- Migration: 0036_backfill_customer_portal_from_hoa.sql
-- Purpose: Backfill generalized customer portal tables from current HOA data
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- Backfill one community customer account per HOA community.
insert into public.customer_accounts (
  tenant_id,
  account_number,
  account_type,
  name,
  status,
  external_account_ref,
  metadata,
  created_at,
  updated_at
)
select
  hc.tenant_id,
  hc.code,
  'community',
  hc.name,
  case hc.status
    when 'active' then 'active'
    else 'inactive'
  end,
  hc.id::text,
  jsonb_build_object(
    'legacy_source', 'hoa_communities',
    'legacy_hoa_id', hc.id,
    'legacy_hoa_code', hc.code
  ),
  hc.created_at,
  hc.updated_at
from public.hoa_communities hc
where not exists (
  select 1
  from public.customer_accounts ca
  where ca.tenant_id = hc.tenant_id
    and ca.account_type = 'community'
    and ca.external_account_ref = hc.id::text
);

-- Backfill HOA addresses into service locations under their community account.
insert into public.service_locations (
  tenant_id,
  customer_account_id,
  line1,
  line2,
  city,
  state,
  postal_code,
  normalized_key,
  status,
  external_location_ref,
  metadata,
  created_at,
  updated_at
)
select
  hc.tenant_id,
  ca.id,
  ha.line1,
  ha.line2,
  ha.city,
  ha.state,
  ha.postal_code,
  ha.normalized_key,
  case ha.is_active
    when true then 'active'
    else 'inactive'
  end,
  ha.id::text,
  jsonb_build_object(
    'legacy_source', 'hoa_addresses',
    'legacy_hoa_id', ha.hoa_id,
    'legacy_address_id', ha.id
  ),
  ha.created_at,
  ha.updated_at
from public.hoa_addresses ha
join public.hoa_communities hc on hc.id = ha.hoa_id
join public.customer_accounts ca
  on ca.tenant_id = hc.tenant_id
  and ca.account_type = 'community'
  and ca.external_account_ref = hc.id::text
where not exists (
  select 1
  from public.service_locations sl
  where sl.tenant_id = hc.tenant_id
    and sl.external_location_ref = ha.id::text
);

-- Backfill HOA board/manager memberships as account-level community memberships.
insert into public.customer_memberships (
  tenant_id,
  user_id,
  customer_account_id,
  service_location_id,
  role_id,
  status,
  is_primary_contact,
  created_by,
  created_at,
  updated_at
)
select
  hc.tenant_id,
  uhm.user_id,
  ca.id,
  null,
  target_role.id,
  case uhm.status
    when 'active' then 'active'
    else 'inactive'
  end,
  false,
  uhm.assigned_by,
  uhm.created_at,
  uhm.updated_at
from public.user_hoa_memberships uhm
join public.hoa_communities hc on hc.id = uhm.hoa_id
join public.customer_accounts ca
  on ca.tenant_id = hc.tenant_id
  and ca.account_type = 'community'
  and ca.external_account_ref = hc.id::text
join public.roles source_role on source_role.id = uhm.role_id
join public.roles target_role on target_role.code = 'community_admin'
where source_role.code in ('hoa_board', 'hoa_manager')
  and not exists (
    select 1
    from public.customer_memberships cm
    where cm.user_id = uhm.user_id
      and cm.customer_account_id = ca.id
      and cm.service_location_id is null
      and cm.role_id = target_role.id
  );
/*
  HOA residents are intentionally not backfilled as account-level customer users
  from user_hoa_memberships. Customer users should be location-scoped through
  user_address_memberships so a resident is not granted access to every service
  location in the community account.
*/

-- Backfill current address memberships as service-location customer memberships.
insert into public.customer_memberships (
  tenant_id,
  user_id,
  customer_account_id,
  service_location_id,
  role_id,
  status,
  is_primary_contact,
  created_by,
  created_at,
  updated_at
)
select
  hc.tenant_id,
  uam.user_id,
  ca.id,
  sl.id,
  customer_role.id,
  case uam.is_current
    when true then 'active'
    else 'inactive'
  end,
  uam.is_primary,
  uam.created_by,
  uam.created_at,
  uam.updated_at
from public.user_address_memberships uam
join public.hoa_communities hc on hc.id = uam.hoa_id
join public.customer_accounts ca
  on ca.tenant_id = hc.tenant_id
  and ca.account_type = 'community'
  and ca.external_account_ref = hc.id::text
join public.service_locations sl
  on sl.tenant_id = hc.tenant_id
  and sl.customer_account_id = ca.id
  and sl.external_location_ref = uam.address_id::text
join public.roles customer_role on customer_role.code = 'customer_user'
where not exists (
  select 1
  from public.customer_memberships cm
  where cm.user_id = uam.user_id
    and cm.customer_account_id = ca.id
    and cm.service_location_id = sl.id
    and cm.role_id = customer_role.id
);

-- Backfill residency verification records into customer verification records.
insert into public.customer_verifications (
  tenant_id,
  user_id,
  email,
  customer_account_id,
  service_location_id,
  verification_method,
  address_matched,
  email_verified,
  status,
  verified_at,
  metadata,
  created_at,
  updated_at
)
select
  hc.tenant_id,
  rv.user_id,
  p.email,
  ca.id,
  sl.id,
  case
    when rv.activation_code_verified then 'activation_code'
    else 'address_email'
  end,
  rv.address_verified,
  rv.email_verified,
  case rv.status
    when 'verified' then case
      when rv.verified_at is not null then 'verified'
      else 'pending'
    end
    when 'failed' then 'failed'
    else 'pending'
  end,
  rv.verified_at,
  jsonb_build_object(
    'legacy_source', 'residency_verifications',
    'legacy_verification_id', rv.id,
    'legacy_hoa_id', rv.hoa_id,
    'legacy_address_id', rv.address_id,
    'activation_code_verified', rv.activation_code_verified
  ),
  rv.created_at,
  rv.updated_at
from public.residency_verifications rv
join public.profiles p on p.id = rv.user_id
join public.hoa_communities hc on hc.id = rv.hoa_id
join public.customer_accounts ca
  on ca.tenant_id = hc.tenant_id
  and ca.account_type = 'community'
  and ca.external_account_ref = hc.id::text
left join public.service_locations sl
  on sl.tenant_id = hc.tenant_id
  and sl.customer_account_id = ca.id
  and sl.external_location_ref = rv.address_id::text
where not exists (
  select 1
  from public.customer_verifications cv
  where (cv.metadata ->> 'legacy_verification_id') = rv.id::text
);

commit;
