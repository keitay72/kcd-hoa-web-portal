-- =========================================================
-- Migration: 0005_content_tables.sql
-- Purpose: Create Phase 1 HOA content and service schedule tables
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  title text not null,
  body text not null,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  status text not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint announcements_title_not_blank check (length(trim(title)) > 0),
  constraint announcements_body_not_blank check (length(trim(body)) > 0),
  constraint announcements_status_valid check (status in ('draft', 'published', 'archived')),
  constraint announcements_publish_window_valid check (expire_at is null or expire_at > publish_at)
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  title text not null,
  category text not null,
  storage_path text not null,
  mime_type text not null,
  file_size bigint not null,
  visibility_scope text not null default 'resident',
  status text not null default 'active',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint documents_title_not_blank check (length(trim(title)) > 0),
  constraint documents_category_not_blank check (length(trim(category)) > 0),
  constraint documents_storage_path_not_blank check (length(trim(storage_path)) > 0),
  constraint documents_file_size_nonnegative check (file_size >= 0),
  constraint documents_visibility_scope_valid check (visibility_scope in ('resident', 'board', 'manager', 'admin')),
  constraint documents_status_valid check (status in ('active', 'archived'))
);

create table if not exists public.service_schedules (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete cascade,
  address_id uuid references public.hoa_addresses(id) on delete set null,
  service_type text not null,
  service_day smallint not null,
  start_date date not null,
  end_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint service_schedules_type_valid check (service_type in ('trash', 'recycling', 'yard_waste', 'bulk')),
  constraint service_schedules_day_valid check (service_day between 0 and 6),
  constraint service_schedules_date_range_valid check (end_date is null or end_date >= start_date)
);

create or replace function public.enforce_service_schedule_hoa_match()
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

drop trigger if exists trg_service_schedule_hoa_match on public.service_schedules;
create trigger trg_service_schedule_hoa_match
before insert or update on public.service_schedules
for each row execute function public.enforce_service_schedule_hoa_match();

commit;
