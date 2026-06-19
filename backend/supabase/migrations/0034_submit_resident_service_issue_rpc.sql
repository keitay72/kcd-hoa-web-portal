-- =========================================================
-- Migration: 0034_submit_resident_service_issue_rpc.sql
-- Purpose: Submit resident service issues through a controlled RPC.
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create or replace function public.submit_resident_service_issue(
  _hoa_id uuid,
  _address_id uuid,
  _type text,
  _subject text,
  _description text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  _ticket_id uuid := gen_random_uuid();
  _requester_user_id uuid;
  _tenant_id uuid;
begin
  if auth.uid() is null then
    raise exception 'sign in before submitting a service issue';
  end if;

  if _type not in ('missed_pickup', 'damaged_cart', 'complaint', 'service_issue') then
    raise exception 'invalid service issue type: %', _type;
  end if;

  if length(trim(coalesce(_subject, ''))) = 0 then
    raise exception 'subject is required';
  end if;

  if length(trim(coalesce(_description, ''))) = 0 then
    raise exception 'description is required';
  end if;

  if not exists (
    select 1
    from public.hoa_addresses a
    where a.id = _address_id
      and a.hoa_id = _hoa_id
      and a.is_active = true
  ) then
    raise exception 'address is not active for this HOA';
  end if;

  _tenant_id := public.hoa_tenant_id(_hoa_id);

  if public.user_has_current_address_membership(auth.uid(), _hoa_id, _address_id) then
    _requester_user_id := auth.uid();
  elsif public.can_operate_tenant(_tenant_id) then
    select uam.user_id
    into _requester_user_id
    from public.user_address_memberships uam
    where uam.hoa_id = _hoa_id
      and uam.address_id = _address_id
      and uam.is_current = true
    order by uam.is_primary desc, uam.start_date desc, uam.created_at desc
    limit 1;
  end if;

  if _requester_user_id is null then
    raise exception 'requester must have a current address membership for this HOA/address';
  end if;

  insert into public.tickets (
    id,
    hoa_id,
    requester_user_id,
    address_id,
    type,
    priority,
    status,
    subject,
    description
  )
  values (
    _ticket_id,
    _hoa_id,
    _requester_user_id,
    _address_id,
    _type,
    'normal',
    'new',
    trim(_subject),
    trim(_description)
  );

  insert into public.ticket_events (
    ticket_id,
    actor_user_id,
    new_status,
    note
  )
  values (
    _ticket_id,
    auth.uid(),
    'new',
    'Resident submitted the service issue.'
  );

  return _ticket_id;
end;
$$;

revoke all on function public.submit_resident_service_issue(uuid, uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_resident_service_issue(uuid, uuid, text, text, text)
  to authenticated;

comment on function public.submit_resident_service_issue(uuid, uuid, text, text, text) is
  'Creates a resident service ticket for the authenticated resident, or for tenant/platform operators testing against a current resident address.';

commit;
