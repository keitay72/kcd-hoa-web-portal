-- =========================================================
-- Migration: 0033_resident_activation_code_settings.sql
-- Purpose: Allow tenants and HOAs to opt out of resident activation codes
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.tenant_settings
  add column if not exists resident_activation_codes_required boolean not null default true;

alter table public.hoa_communities
  add column if not exists resident_activation_codes_required_override boolean;

comment on column public.tenant_settings.resident_activation_codes_required is
  'Tenant default for requiring resident activation codes during self-registration.';

comment on column public.hoa_communities.resident_activation_codes_required_override is
  'Optional HOA override for resident activation codes. Null inherits the tenant setting.';

create or replace function public.resident_activation_code_required(_hoa_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    hc.resident_activation_codes_required_override,
    ts.resident_activation_codes_required,
    true
  )
  from public.hoa_communities hc
  left join public.tenant_settings ts on ts.tenant_id = hc.tenant_id
  where hc.id = _hoa_id
$$;

grant execute on function public.resident_activation_code_required(uuid) to authenticated;
grant execute on function public.resident_activation_code_required(uuid) to service_role;

commit;
