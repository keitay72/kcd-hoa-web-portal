-- =========================================================
-- Migration: 0003_hoa_tables.sql
-- Purpose: Create Phase 1 HOA community, address, and membership tables
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.hoa_communities (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete restrict,
  code text unique not null,
  name text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint hoa_communities_code_valid check (code ~ '^[A-Z][A-Z0-9_]*$'),
  constraint hoa_communities_name_not_blank check (length(trim(name)) > 0),
  constraint hoa_communities_status_valid check (status in ('active', 'inactive'))
);

create table if not exists public.hoa_addresses (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  line1 text not null,
  line2 text,
  city text not null,
  state text not null,
  postal_code text not null,
  normalized_key text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint hoa_addresses_line1_not_blank check (length(trim(line1)) > 0),
  constraint hoa_addresses_city_not_blank check (length(trim(city)) > 0),
  constraint hoa_addresses_state_valid check (state ~ '^[A-Z]{2}$'),
  constraint hoa_addresses_postal_not_blank check (length(trim(postal_code)) > 0),
  constraint hoa_addresses_normalized_not_blank check (length(trim(normalized_key)) > 0),
  constraint hoa_addresses_unique_normalized unique (hoa_id, normalized_key)
);

create table if not exists public.user_hoa_memberships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,

  primary key (user_id, hoa_id, role_id),
  constraint user_hoa_memberships_status_valid check (status in ('active', 'inactive'))
);

create table if not exists public.user_address_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  hoa_id uuid not null references public.hoa_communities(id) on delete restrict,
  address_id uuid not null references public.hoa_addresses(id) on delete restrict,
  occupancy_type text not null default 'resident',
  is_primary boolean not null default true,
  is_current boolean not null default true,
  start_date date not null default current_date,
  end_date date,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_address_memberships_occupancy_valid check (occupancy_type in ('resident', 'owner', 'tenant')),
  constraint user_address_memberships_current_end_date_valid check (
    (is_current = true and end_date is null)
    or (is_current = false)
  ),
  constraint user_address_memberships_date_range_valid check (
    end_date is null or end_date >= start_date
  ),
  constraint user_address_memberships_unique_start unique (user_id, address_id, start_date)
);

create unique index if not exists uq_user_address_current_primary
  on public.user_address_memberships(user_id)
  where is_current = true and is_primary = true;

create unique index if not exists uq_user_address_current_unique
  on public.user_address_memberships(user_id, address_id)
  where is_current = true;

-- Enforce address-based HOA assignment. The HOA on membership records must be
-- derived from the address itself, not chosen independently by the resident.
create or replace function public.enforce_user_address_hoa_match()
returns trigger
language plpgsql
as $$
declare
  address_hoa_id uuid;
begin
  select hoa_id
  into address_hoa_id
  from public.hoa_addresses
  where id = new.address_id;

  if address_hoa_id is null then
    raise exception 'address_id % does not exist', new.address_id;
  end if;

  if new.hoa_id <> address_hoa_id then
    raise exception 'hoa_id must match the HOA assigned to address_id %', new.address_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_user_address_hoa_match on public.user_address_memberships;
create trigger trg_user_address_hoa_match
before insert or update on public.user_address_memberships
for each row execute function public.enforce_user_address_hoa_match();

commit;
