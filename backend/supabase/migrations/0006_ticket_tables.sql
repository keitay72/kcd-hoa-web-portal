-- =========================================================
-- Migration: 0006_ticket_tables.sql
-- Purpose: Create Phase 1 service ticket and attachment metadata tables
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  hoa_id uuid not null references public.hoa_communities(id) on delete restrict,
  requester_user_id uuid not null references public.profiles(id) on delete restrict,
  address_id uuid references public.hoa_addresses(id) on delete set null,
  type text not null,
  priority text not null default 'normal',
  status text not null default 'new',
  subject text not null,
  description text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tickets_type_valid check (type in ('missed_pickup', 'damaged_cart', 'complaint', 'service_issue')),
  constraint tickets_priority_valid check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint tickets_status_valid check (status in ('new', 'triaged', 'assigned', 'in_progress', 'resolved', 'closed', 'reopened')),
  constraint tickets_subject_not_blank check (length(trim(subject)) > 0),
  constraint tickets_description_not_blank check (length(trim(description)) > 0)
);

create table if not exists public.ticket_events (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  old_status text,
  new_status text,
  note text,
  created_at timestamptz not null default now(),

  constraint ticket_events_old_status_valid check (
    old_status is null
    or old_status in ('new', 'triaged', 'assigned', 'in_progress', 'resolved', 'closed', 'reopened')
  ),
  constraint ticket_events_new_status_valid check (
    new_status is null
    or new_status in ('new', 'triaged', 'assigned', 'in_progress', 'resolved', 'closed', 'reopened')
  )
);

create table if not exists public.ticket_attachments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  storage_path text not null,
  mime_type text not null,
  file_size bigint not null,
  scan_status text not null default 'pending',
  created_at timestamptz not null default now(),

  constraint ticket_attachments_storage_path_not_blank check (length(trim(storage_path)) > 0),
  constraint ticket_attachments_file_size_nonnegative check (file_size >= 0),
  constraint ticket_attachments_scan_status_valid check (scan_status in ('pending', 'clean', 'blocked'))
);

create or replace function public.enforce_ticket_hoa_match()
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

create or replace function public.enforce_ticket_requester_membership()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1
    from public.user_address_memberships uam
    where uam.user_id = new.requester_user_id
      and uam.hoa_id = new.hoa_id
      and (new.address_id is null or uam.address_id = new.address_id)
      and uam.is_current = true
  ) then
    raise exception 'requester must have a current address membership for the ticket HOA/address';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ticket_hoa_match on public.tickets;
create trigger trg_ticket_hoa_match
before insert or update on public.tickets
for each row execute function public.enforce_ticket_hoa_match();

drop trigger if exists trg_ticket_requester_membership on public.tickets;
create trigger trg_ticket_requester_membership
before insert or update on public.tickets
for each row execute function public.enforce_ticket_requester_membership();

commit;
