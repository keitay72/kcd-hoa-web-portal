-- =========================================================
-- Migration: 0004_verification_tables.sql
-- Purpose: Create Phase 1 three-factor resident verification tables
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.residency_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  hoa_id uuid not null references public.hoa_communities(id) on delete restrict,
  address_id uuid references public.hoa_addresses(id) on delete restrict,
  address_verified boolean not null default false,
  email_verified boolean not null default false,
  activation_code_verified boolean not null default false,
  status text not null default 'pending',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint residency_verifications_status_valid check (status in ('pending', 'verified', 'failed')),
  constraint residency_verifications_unique_user_hoa unique (user_id, hoa_id),
  constraint residency_verifications_verified_state_valid check (
    (
      status = 'verified'
      and address_verified = true
      and email_verified = true
      and activation_code_verified = true
      and verified_at is not null
    )
    or status <> 'verified'
  )
);

create table if not exists public.activation_codes (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  address_id uuid not null references public.hoa_addresses(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references public.profiles(id) on delete set null,
  reset_count int not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint activation_codes_status_valid check (status in ('active', 'consumed', 'expired', 'revoked')),
  constraint activation_codes_hash_not_blank check (length(trim(code_hash)) > 0),
  constraint activation_codes_reset_count_nonnegative check (reset_count >= 0),
  constraint activation_codes_consumed_state_valid check (
    (status = 'consumed' and consumed_at is not null and consumed_by is not null)
    or status <> 'consumed'
  )
);

-- Correct uniqueness rule: allow historical consumed/expired/revoked codes,
-- but only one active code for a given address at a time.
create unique index if not exists uq_activation_codes_one_active_per_address
  on public.activation_codes(address_id)
  where status = 'active';

create table if not exists public.activation_code_events (
  id uuid primary key default gen_random_uuid(),
  activation_code_id uuid not null references public.activation_codes(id) on delete cascade,
  action text not null,
  actor_user_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),

  constraint activation_code_events_action_valid check (action in ('created', 'reset', 'consumed', 'revoked', 'expired'))
);

create or replace function public.enforce_residency_verification_hoa_match()
returns trigger
language plpgsql
as $$
declare
  address_hoa_id uuid;
begin
  if new.address_id is null then
    return new;
  end if;

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

create or replace function public.enforce_activation_code_hoa_match()
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

drop trigger if exists trg_residency_verification_hoa_match on public.residency_verifications;
create trigger trg_residency_verification_hoa_match
before insert or update on public.residency_verifications
for each row execute function public.enforce_residency_verification_hoa_match();

drop trigger if exists trg_activation_code_hoa_match on public.activation_codes;
create trigger trg_activation_code_hoa_match
before insert or update on public.activation_codes
for each row execute function public.enforce_activation_code_hoa_match();

commit;
