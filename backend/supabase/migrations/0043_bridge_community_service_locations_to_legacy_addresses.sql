-- =========================================================
-- Migration: 0043_bridge_community_service_locations_to_legacy_addresses.sql
-- Purpose: Keep community service locations compatible with the
-- legacy HOA ticket tables until ticket storage is moved to the
-- customer portal schema.
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

with community_locations as (
  select
    sl.id as service_location_id,
    (
      coalesce(
        sl.metadata ->> 'legacy_hoa_id',
        case
          when ca.account_type = 'community' then ca.external_account_ref
          else null
        end
      )
    )::uuid as legacy_hoa_id,
    sl.line1,
    sl.line2,
    sl.city,
    sl.state,
    sl.postal_code,
    sl.normalized_key
  from public.service_locations sl
  join public.customer_accounts ca
    on ca.id = sl.customer_account_id
  where sl.status = 'active'
    and coalesce(
      sl.metadata ->> 'legacy_hoa_id',
      case
        when ca.account_type = 'community' then ca.external_account_ref
        else null
      end
    ) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
),
upserted_addresses as (
  insert into public.hoa_addresses (
    hoa_id,
    line1,
    line2,
    city,
    state,
    postal_code,
    normalized_key,
    is_active
  )
  select
    legacy_hoa_id,
    line1,
    nullif(trim(coalesce(line2, '')), ''),
    city,
    state,
    postal_code,
    normalized_key,
    true
  from community_locations
  on conflict (hoa_id, normalized_key) do update
    set line1 = excluded.line1,
        line2 = excluded.line2,
        city = excluded.city,
        state = excluded.state,
        postal_code = excluded.postal_code,
        is_active = true
  returning id, hoa_id, normalized_key
)
update public.service_locations sl
set metadata =
  coalesce(sl.metadata, '{}'::jsonb)
  || jsonb_build_object(
    'legacy_hoa_id', cl.legacy_hoa_id::text,
    'legacy_address_id', ua.id::text
  )
from community_locations cl
join upserted_addresses ua
  on ua.hoa_id = cl.legacy_hoa_id
 and ua.normalized_key = cl.normalized_key
where sl.id = cl.service_location_id;

comment on column public.service_locations.metadata is
  'JSON metadata for service-location integrations. Community locations may include legacy_hoa_id and legacy_address_id while legacy HOA ticket tables remain in use.';

commit;
