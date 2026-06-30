-- Add a city-scoped community type so non-HOA residential service
-- locations can receive city-wide documents, announcements, schedules,
-- contacts, and ticket context through the same community content model.

alter table public.hoa_communities
  add column if not exists community_type text not null default 'hoa',
  add column if not exists city text,
  add column if not exists state text;

update public.hoa_communities
set community_type = 'hoa'
where community_type is null;

alter table public.hoa_communities
  drop constraint if exists hoa_communities_type_valid,
  drop constraint if exists hoa_communities_city_required_for_city,
  drop constraint if exists hoa_communities_state_valid;

alter table public.hoa_communities
  add constraint hoa_communities_type_valid
    check (community_type in ('hoa', 'city')),
  add constraint hoa_communities_city_required_for_city
    check (
      community_type <> 'city'
      or (city is not null and length(trim(city)) > 0)
    ),
  add constraint hoa_communities_state_valid
    check (state is null or state ~ '^[A-Z]{2}$');

create index if not exists idx_hoa_communities_tenant_type_city
  on public.hoa_communities(tenant_id, community_type, city, state);
