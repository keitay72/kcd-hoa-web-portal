-- =========================================================
-- Migration: 0014_service_schedule_hoa_wide_model.sql
-- Purpose: Promote service schedules to HOA-wide rules with optional address overrides
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_schedules'
      and column_name = 'start_date'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_schedules'
      and column_name = 'effective_date'
  ) then
    alter table public.service_schedules rename column start_date to effective_date;
  end if;
end $$;

alter table public.service_schedules
  add column if not exists schedule_rule text,
  add column if not exists route_name text,
  add column if not exists status text not null default 'active';

alter table public.service_schedules
  alter column service_day drop not null,
  alter column effective_date set not null,
  alter column status set default 'active';

update public.service_schedules
set schedule_rule = case service_day
  when 0 then 'Sunday'
  when 1 then 'Monday'
  when 2 then 'Tuesday'
  when 3 then 'Wednesday'
  when 4 then 'Thursday'
  when 5 then 'Friday'
  when 6 then 'Saturday'
  else 'Custom schedule'
end
where schedule_rule is null or length(trim(schedule_rule)) = 0;

update public.service_schedules
set status = case
  when end_date is not null and end_date <= current_date then 'archived'
  else 'active'
end
where status is null or status not in ('active', 'archived');

alter table public.service_schedules
  alter column schedule_rule set not null;

alter table public.service_schedules
  drop constraint if exists service_schedules_rule_not_blank,
  add constraint service_schedules_rule_not_blank check (length(trim(schedule_rule)) > 0),
  drop constraint if exists service_schedules_route_name_not_blank,
  add constraint service_schedules_route_name_not_blank check (route_name is null or length(trim(route_name)) > 0),
  drop constraint if exists service_schedules_status_valid,
  add constraint service_schedules_status_valid check (status in ('active', 'archived'));

drop index if exists idx_service_schedules_hoa_service_active_default;
create unique index idx_service_schedules_hoa_service_active_default
on public.service_schedules(hoa_id, service_type)
where address_id is null and status = 'active';

drop index if exists idx_service_schedules_address_service_active_override;
create unique index idx_service_schedules_address_service_active_override
on public.service_schedules(address_id, service_type)
where address_id is not null and status = 'active';

create index if not exists idx_service_schedules_hoa_status_type
on public.service_schedules(hoa_id, status, service_type);

comment on column public.service_schedules.schedule_rule is
  'Human-readable HOA-wide schedule rule, such as Tuesday, Thursday, or First Saturday.';
comment on column public.service_schedules.route_name is
  'Optional route label used by KC Disposal operations.';
comment on column public.service_schedules.address_id is
  'Optional address-specific override. Null means HOA-wide default schedule.';
comment on column public.service_schedules.status is
  'Schedule lifecycle status. Archived schedules are retained historically.';

commit;
