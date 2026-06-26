-- =========================================================
-- Migration: 0049_customer_verification_default_no_activation_codes.sql
-- Purpose: Make address/email verification the default customer signup model
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.tenant_settings
  alter column resident_activation_codes_required set default false;

update public.tenant_settings
set resident_activation_codes_required = false
where resident_activation_codes_required = true;

comment on column public.tenant_settings.resident_activation_codes_required is
  'Legacy activation-code compatibility flag retained for migration history. New customer signup uses service address match plus email verification.';

comment on column public.hoa_communities.resident_activation_codes_required_override is
  'Legacy activation-code compatibility override retained for migration history. New customer signup uses service address match plus email verification.';

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
    false
  )
  from public.hoa_communities hc
  left join public.tenant_settings ts on ts.tenant_id = hc.tenant_id
  where hc.id = _hoa_id
$$;

grant execute on function public.resident_activation_code_required(uuid) to authenticated;
grant execute on function public.resident_activation_code_required(uuid) to service_role;

commit;
