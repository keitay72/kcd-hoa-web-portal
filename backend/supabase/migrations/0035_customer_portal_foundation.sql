-- =========================================================
-- Migration: 0035_customer_portal_foundation.sql
-- Purpose: Add generalized customer account and service location foundation
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- Expand role scope vocabulary for the customer portal model while preserving
-- existing HOA/resident scope values used by current app workflows.
alter table public.roles
  drop constraint if exists roles_role_scope_valid;

alter table public.roles
  add constraint roles_role_scope_valid
  check (role_scope in ('platform', 'tenant', 'hoa', 'resident', 'community', 'customer'));

insert into public.roles (code, name, description, is_system, role_scope, lifecycle_status)
values
  (
    'community_admin',
    'Community Admin',
    'Community-level customer admin for HOA board members, property managers, or similar community contacts.',
    true,
    'community',
    'active'
  ),
  (
    'customer_user',
    'Customer User',
    'Customer portal user with access to assigned customer accounts or service locations.',
    true,
    'customer',
    'active'
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  is_system = excluded.is_system,
  role_scope = excluded.role_scope,
  lifecycle_status = excluded.lifecycle_status;

insert into public.permissions (code, name, description)
values
  ('customer_accounts.read', 'Read customer accounts', 'Read customer account records'),
  ('customer_accounts.manage', 'Manage customer accounts', 'Create and update customer account records'),
  ('service_locations.read', 'Read service locations', 'Read service location records'),
  ('service_locations.manage', 'Manage service locations', 'Create and update service location records'),
  ('customer_memberships.read', 'Read customer memberships', 'Read customer account and service-location membership records'),
  ('customer_memberships.manage', 'Manage customer memberships', 'Create and update customer account and service-location memberships'),
  ('customer_verifications.read', 'Read customer verifications', 'Read customer signup and verification records'),
  ('customer_verifications.manage', 'Manage customer verifications', 'Create and update customer signup and verification records')
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description;

with role_permission_map(role_code, permission_code) as (
  values
    ('platform_owner', 'customer_accounts.read'),
    ('platform_owner', 'customer_accounts.manage'),
    ('platform_owner', 'service_locations.read'),
    ('platform_owner', 'service_locations.manage'),
    ('platform_owner', 'customer_memberships.read'),
    ('platform_owner', 'customer_memberships.manage'),
    ('platform_owner', 'customer_verifications.read'),
    ('platform_owner', 'customer_verifications.manage'),

    ('platform_admin', 'customer_accounts.read'),
    ('platform_admin', 'customer_accounts.manage'),
    ('platform_admin', 'service_locations.read'),
    ('platform_admin', 'service_locations.manage'),
    ('platform_admin', 'customer_memberships.read'),
    ('platform_admin', 'customer_memberships.manage'),
    ('platform_admin', 'customer_verifications.read'),
    ('platform_admin', 'customer_verifications.manage'),

    ('platform_support', 'customer_accounts.read'),
    ('platform_support', 'service_locations.read'),
    ('platform_support', 'customer_memberships.read'),
    ('platform_support', 'customer_verifications.read'),

    ('platform_sales', 'customer_accounts.read'),
    ('platform_sales', 'service_locations.read'),

    ('community_admin', 'profiles.read'),
    ('community_admin', 'customer_accounts.read'),
    ('community_admin', 'service_locations.read'),
    ('community_admin', 'customer_memberships.read'),
    ('community_admin', 'customer_verifications.read'),
    ('community_admin', 'announcements.read'),
    ('community_admin', 'announcements.manage'),
    ('community_admin', 'documents.read'),
    ('community_admin', 'documents.manage'),
    ('community_admin', 'schedules.read'),
    ('community_admin', 'tickets.read'),
    ('community_admin', 'ticket_attachments.read'),

    ('customer_user', 'profiles.read'),
    ('customer_user', 'profiles.update'),
    ('customer_user', 'customer_accounts.read'),
    ('customer_user', 'service_locations.read'),
    ('customer_user', 'customer_memberships.read'),
    ('customer_user', 'customer_verifications.read'),
    ('customer_user', 'announcements.read'),
    ('customer_user', 'documents.read'),
    ('customer_user', 'schedules.read'),
    ('customer_user', 'tickets.create'),
    ('customer_user', 'tickets.read'),
    ('customer_user', 'ticket_attachments.create'),
    ('customer_user', 'ticket_attachments.read'),

    ('tenant_admin', 'customer_accounts.read'),
    ('tenant_admin', 'customer_accounts.manage'),
    ('tenant_admin', 'service_locations.read'),
    ('tenant_admin', 'service_locations.manage'),
    ('tenant_admin', 'customer_memberships.read'),
    ('tenant_admin', 'customer_memberships.manage'),
    ('tenant_admin', 'customer_verifications.read'),
    ('tenant_admin', 'customer_verifications.manage'),

    ('tenant_manager', 'customer_accounts.read'),
    ('tenant_manager', 'customer_accounts.manage'),
    ('tenant_manager', 'service_locations.read'),
    ('tenant_manager', 'service_locations.manage'),
    ('tenant_manager', 'customer_memberships.read'),
    ('tenant_manager', 'customer_memberships.manage'),
    ('tenant_manager', 'customer_verifications.read'),
    ('tenant_manager', 'customer_verifications.manage'),

    ('tenant_csr', 'customer_accounts.read'),
    ('tenant_csr', 'customer_accounts.manage'),
    ('tenant_csr', 'service_locations.read'),
    ('tenant_csr', 'service_locations.manage'),
    ('tenant_csr', 'customer_memberships.read'),
    ('tenant_csr', 'customer_memberships.manage'),
    ('tenant_csr', 'customer_verifications.read'),
    ('tenant_csr', 'customer_verifications.manage'),

    ('tenant_dispatch', 'customer_accounts.read'),
    ('tenant_dispatch', 'service_locations.read'),
    ('tenant_dispatch', 'customer_memberships.read')
)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from role_permission_map rpm
join public.roles r on r.code = rpm.role_code
join public.permissions p on p.code = rpm.permission_code
on conflict (role_id, permission_id) do nothing;

create table if not exists public.customer_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete restrict,
  account_number text,
  account_type text not null,
  name text,
  status text not null default 'active',
  external_account_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_accounts_account_number_not_blank check (account_number is null or length(trim(account_number)) > 0),
  constraint customer_accounts_type_valid check (account_type in ('residential', 'community', 'commercial', 'roll_off')),
  constraint customer_accounts_name_not_blank check (name is null or length(trim(name)) > 0),
  constraint customer_accounts_status_valid check (status in ('active', 'inactive', 'suspended')),
  constraint customer_accounts_external_ref_not_blank check (external_account_ref is null or length(trim(external_account_ref)) > 0)
);

create unique index if not exists uq_customer_accounts_tenant_account_number
  on public.customer_accounts(tenant_id, account_number)
  where account_number is not null;

create index if not exists idx_customer_accounts_tenant_type_status
  on public.customer_accounts(tenant_id, account_type, status);

create table if not exists public.service_locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete restrict,
  customer_account_id uuid not null references public.customer_accounts(id) on delete cascade,
  line1 text not null,
  line2 text,
  city text not null,
  state text not null,
  postal_code text not null,
  normalized_key text not null,
  status text not null default 'active',
  external_location_ref text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint service_locations_line1_not_blank check (length(trim(line1)) > 0),
  constraint service_locations_line2_not_blank check (line2 is null or length(trim(line2)) > 0),
  constraint service_locations_city_not_blank check (length(trim(city)) > 0),
  constraint service_locations_state_valid check (state ~ '^[A-Z]{2}$'),
  constraint service_locations_postal_not_blank check (length(trim(postal_code)) > 0),
  constraint service_locations_normalized_not_blank check (length(trim(normalized_key)) > 0),
  constraint service_locations_status_valid check (status in ('active', 'inactive')),
  constraint service_locations_external_ref_not_blank check (external_location_ref is null or length(trim(external_location_ref)) > 0)
);

create unique index if not exists uq_service_locations_account_normalized
  on public.service_locations(customer_account_id, normalized_key);

create index if not exists idx_service_locations_tenant_normalized
  on public.service_locations(tenant_id, normalized_key);

create index if not exists idx_service_locations_tenant_status
  on public.service_locations(tenant_id, status);

create table if not exists public.customer_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  customer_account_id uuid not null references public.customer_accounts(id) on delete cascade,
  service_location_id uuid references public.service_locations(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  status text not null default 'active',
  is_primary_contact boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_memberships_status_valid check (status in ('pending', 'active', 'inactive', 'revoked'))
);

create unique index if not exists uq_customer_memberships_active_scope
  on public.customer_memberships(
    user_id,
    customer_account_id,
    coalesce(service_location_id, '00000000-0000-0000-0000-000000000000'::uuid),
    role_id
  )
  where status in ('pending', 'active');

create index if not exists idx_customer_memberships_user_status
  on public.customer_memberships(user_id, status);

create index if not exists idx_customer_memberships_tenant_account_status
  on public.customer_memberships(tenant_id, customer_account_id, status);

create index if not exists idx_customer_memberships_location_status
  on public.customer_memberships(service_location_id, status)
  where service_location_id is not null;

create table if not exists public.customer_verifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete restrict,
  user_id uuid references public.profiles(id) on delete cascade,
  email citext not null,
  customer_account_id uuid references public.customer_accounts(id) on delete set null,
  service_location_id uuid references public.service_locations(id) on delete set null,
  verification_method text not null default 'address_email',
  address_matched boolean not null default false,
  email_verified boolean not null default false,
  status text not null default 'pending',
  verified_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_verifications_email_not_blank check (length(trim(email::text)) > 0),
  constraint customer_verifications_method_valid check (verification_method in ('address_email', 'activation_code', 'manual_review', 'account_number')),
  constraint customer_verifications_status_valid check (status in ('pending', 'email_sent', 'verified', 'failed', 'expired', 'cancelled')),
  constraint customer_verifications_verified_at_valid check ((status = 'verified' and verified_at is not null) or status <> 'verified')
);

create index if not exists idx_customer_verifications_tenant_email_status
  on public.customer_verifications(tenant_id, email, status);

create index if not exists idx_customer_verifications_user_status
  on public.customer_verifications(user_id, status)
  where user_id is not null;

create index if not exists idx_customer_verifications_location_status
  on public.customer_verifications(service_location_id, status)
  where service_location_id is not null;

create table if not exists public.tenant_usage_snapshots (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.platform_tenants(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  active_customer_account_count integer not null default 0,
  active_service_location_count integer not null default 0,
  active_customer_user_count integer not null default 0,
  plan_limit integer,
  grace_limit integer,
  billable_overage_count integer not null default 0,
  created_at timestamptz not null default now(),

  constraint tenant_usage_snapshots_period_valid check (period_end >= period_start),
  constraint tenant_usage_snapshots_account_count_nonnegative check (active_customer_account_count >= 0),
  constraint tenant_usage_snapshots_location_count_nonnegative check (active_service_location_count >= 0),
  constraint tenant_usage_snapshots_user_count_nonnegative check (active_customer_user_count >= 0),
  constraint tenant_usage_snapshots_plan_limit_nonnegative check (plan_limit is null or plan_limit >= 0),
  constraint tenant_usage_snapshots_grace_limit_nonnegative check (grace_limit is null or grace_limit >= 0),
  constraint tenant_usage_snapshots_overage_nonnegative check (billable_overage_count >= 0),
  constraint tenant_usage_snapshots_unique_period unique (tenant_id, period_start, period_end)
);

alter table public.subscription_plans
  add column if not exists included_service_location_count integer,
  add column if not exists service_location_overage_cents integer,
  add column if not exists service_location_grace_percent integer not null default 5;

alter table public.subscription_plans
  drop constraint if exists subscription_plans_included_service_location_count_positive,
  add constraint subscription_plans_included_service_location_count_positive
  check (included_service_location_count is null or included_service_location_count >= 0),
  drop constraint if exists subscription_plans_service_location_overage_cents_positive,
  add constraint subscription_plans_service_location_overage_cents_positive
  check (service_location_overage_cents is null or service_location_overage_cents >= 0),
  drop constraint if exists subscription_plans_service_location_grace_percent_valid,
  add constraint subscription_plans_service_location_grace_percent_valid
  check (service_location_grace_percent between 0 and 100);

create or replace function public.enforce_service_location_account_match()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_tenant_id uuid;
begin
  select ca.tenant_id
  into account_tenant_id
  from public.customer_accounts ca
  where ca.id = new.customer_account_id;

  if account_tenant_id is null then
    raise exception 'customer_account_id % does not exist', new.customer_account_id;
  end if;

  if new.tenant_id <> account_tenant_id then
    raise exception 'service location tenant_id must match customer account tenant_id';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_customer_membership_scope_match()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_tenant_id uuid;
  location_tenant_id uuid;
  location_account_id uuid;
begin
  select ca.tenant_id
  into account_tenant_id
  from public.customer_accounts ca
  where ca.id = new.customer_account_id;

  if account_tenant_id is null then
    raise exception 'customer_account_id % does not exist', new.customer_account_id;
  end if;

  if new.tenant_id <> account_tenant_id then
    raise exception 'customer membership tenant_id must match customer account tenant_id';
  end if;

  if new.service_location_id is not null then
    select sl.tenant_id, sl.customer_account_id
    into location_tenant_id, location_account_id
    from public.service_locations sl
    where sl.id = new.service_location_id;

    if location_tenant_id is null then
      raise exception 'service_location_id % does not exist', new.service_location_id;
    end if;

    if new.tenant_id <> location_tenant_id or new.customer_account_id <> location_account_id then
      raise exception 'customer membership service location must match tenant and customer account';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.enforce_customer_verification_scope_match()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  account_tenant_id uuid;
  location_tenant_id uuid;
  location_account_id uuid;
begin
  if new.customer_account_id is not null then
    select ca.tenant_id
    into account_tenant_id
    from public.customer_accounts ca
    where ca.id = new.customer_account_id;

    if account_tenant_id is null then
      raise exception 'customer_account_id % does not exist', new.customer_account_id;
    end if;

    if new.tenant_id <> account_tenant_id then
      raise exception 'customer verification tenant_id must match customer account tenant_id';
    end if;
  end if;

  if new.service_location_id is not null then
    select sl.tenant_id, sl.customer_account_id
    into location_tenant_id, location_account_id
    from public.service_locations sl
    where sl.id = new.service_location_id;

    if location_tenant_id is null then
      raise exception 'service_location_id % does not exist', new.service_location_id;
    end if;

    if new.tenant_id <> location_tenant_id then
      raise exception 'customer verification service location tenant_id must match tenant_id';
    end if;

    if new.customer_account_id is not null and new.customer_account_id <> location_account_id then
      raise exception 'customer verification service location must match customer account';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_service_location_account_match on public.service_locations;
create trigger trg_service_location_account_match
before insert or update on public.service_locations
for each row execute function public.enforce_service_location_account_match();

drop trigger if exists trg_customer_membership_scope_match on public.customer_memberships;
create trigger trg_customer_membership_scope_match
before insert or update on public.customer_memberships
for each row execute function public.enforce_customer_membership_scope_match();

drop trigger if exists trg_customer_verification_scope_match on public.customer_verifications;
create trigger trg_customer_verification_scope_match
before insert or update on public.customer_verifications
for each row execute function public.enforce_customer_verification_scope_match();

drop trigger if exists trg_customer_accounts_updated_at on public.customer_accounts;
create trigger trg_customer_accounts_updated_at
before update on public.customer_accounts
for each row execute function public.set_updated_at();

drop trigger if exists trg_service_locations_updated_at on public.service_locations;
create trigger trg_service_locations_updated_at
before update on public.service_locations
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_memberships_updated_at on public.customer_memberships;
create trigger trg_customer_memberships_updated_at
before update on public.customer_memberships
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_verifications_updated_at on public.customer_verifications;
create trigger trg_customer_verifications_updated_at
before update on public.customer_verifications
for each row execute function public.set_updated_at();

create or replace function public.customer_account_tenant_id(_customer_account_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select ca.tenant_id
  from public.customer_accounts ca
  where ca.id = _customer_account_id;
$$;

create or replace function public.service_location_tenant_id(_service_location_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select sl.tenant_id
  from public.service_locations sl
  where sl.id = _service_location_id;
$$;

create or replace function public.user_has_customer_account_role(_customer_account_id uuid, _roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.customer_memberships cm
    join public.roles r on r.id = cm.role_id
    where cm.user_id = auth.uid()
      and cm.customer_account_id = _customer_account_id
      and cm.status = 'active'
      and r.code = any(_roles)
  );
$$;

create or replace function public.user_has_service_location_role(_service_location_id uuid, _roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.customer_memberships cm
    join public.roles r on r.id = cm.role_id
    where cm.user_id = auth.uid()
      and cm.service_location_id = _service_location_id
      and cm.status = 'active'
      and r.code = any(_roles)
  );
$$;

create or replace function public.user_can_access_customer_account(_customer_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.can_access_tenant(public.customer_account_tenant_id(_customer_account_id))
    or exists (
      select 1
      from public.customer_memberships cm
      where cm.user_id = auth.uid()
        and cm.customer_account_id = _customer_account_id
        and cm.status = 'active'
    );
$$;

create or replace function public.user_can_access_service_location(_service_location_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.can_access_tenant(public.service_location_tenant_id(_service_location_id))
    or exists (
      select 1
      from public.customer_memberships cm
      where cm.user_id = auth.uid()
        and cm.status = 'active'
        and (
          cm.service_location_id = _service_location_id
          or (
            cm.service_location_id is null
            and cm.customer_account_id = (
              select sl.customer_account_id
              from public.service_locations sl
              where sl.id = _service_location_id
            )
          )
        )
    );
$$;

revoke all on function public.enforce_service_location_account_match() from public, anon, authenticated;
revoke all on function public.enforce_customer_membership_scope_match() from public, anon, authenticated;
revoke all on function public.enforce_customer_verification_scope_match() from public, anon, authenticated;
revoke all on function public.customer_account_tenant_id(uuid) from public, anon, authenticated;
revoke all on function public.service_location_tenant_id(uuid) from public, anon, authenticated;
revoke all on function public.user_has_customer_account_role(uuid, text[]) from public, anon, authenticated;
revoke all on function public.user_has_service_location_role(uuid, text[]) from public, anon, authenticated;
revoke all on function public.user_can_access_customer_account(uuid) from public, anon, authenticated;
revoke all on function public.user_can_access_service_location(uuid) from public, anon, authenticated;

grant execute on function public.customer_account_tenant_id(uuid) to authenticated;
grant execute on function public.service_location_tenant_id(uuid) to authenticated;
grant execute on function public.user_has_customer_account_role(uuid, text[]) to authenticated;
grant execute on function public.user_has_service_location_role(uuid, text[]) to authenticated;
grant execute on function public.user_can_access_customer_account(uuid) to authenticated;
grant execute on function public.user_can_access_service_location(uuid) to authenticated;

alter table public.customer_accounts enable row level security;
alter table public.service_locations enable row level security;
alter table public.customer_memberships enable row level security;
alter table public.customer_verifications enable row level security;
alter table public.tenant_usage_snapshots enable row level security;

drop policy if exists customer_accounts_select_scoped on public.customer_accounts;
create policy customer_accounts_select_scoped
on public.customer_accounts
for select
to authenticated
using (
  public.can_access_tenant(tenant_id)
  or public.user_can_access_customer_account(id)
);

drop policy if exists customer_accounts_manage_tenant on public.customer_accounts;
create policy customer_accounts_manage_tenant
on public.customer_accounts
for all
to authenticated
using (public.can_operate_tenant(tenant_id))
with check (public.can_operate_tenant(tenant_id));

drop policy if exists service_locations_select_scoped on public.service_locations;
create policy service_locations_select_scoped
on public.service_locations
for select
to authenticated
using (
  public.can_access_tenant(tenant_id)
  or public.user_can_access_service_location(id)
);

drop policy if exists service_locations_manage_tenant on public.service_locations;
create policy service_locations_manage_tenant
on public.service_locations
for all
to authenticated
using (public.can_operate_tenant(tenant_id))
with check (public.can_operate_tenant(tenant_id));

drop policy if exists customer_memberships_select_scoped on public.customer_memberships;
create policy customer_memberships_select_scoped
on public.customer_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or public.can_access_tenant(tenant_id)
  or public.user_can_access_customer_account(customer_account_id)
);

drop policy if exists customer_memberships_manage_tenant on public.customer_memberships;
create policy customer_memberships_manage_tenant
on public.customer_memberships
for all
to authenticated
using (public.can_operate_tenant(tenant_id))
with check (public.can_operate_tenant(tenant_id));

drop policy if exists customer_verifications_select_scoped on public.customer_verifications;
create policy customer_verifications_select_scoped
on public.customer_verifications
for select
to authenticated
using (
  user_id = auth.uid()
  or public.can_access_tenant(tenant_id)
  or (
    customer_account_id is not null
    and public.user_can_access_customer_account(customer_account_id)
  )
);

drop policy if exists customer_verifications_manage_tenant on public.customer_verifications;
create policy customer_verifications_manage_tenant
on public.customer_verifications
for all
to authenticated
using (public.can_operate_tenant(tenant_id))
with check (public.can_operate_tenant(tenant_id));

drop policy if exists tenant_usage_snapshots_select_scoped on public.tenant_usage_snapshots;
create policy tenant_usage_snapshots_select_scoped
on public.tenant_usage_snapshots
for select
to authenticated
using (public.can_access_tenant(tenant_id));

drop policy if exists tenant_usage_snapshots_manage_platform on public.tenant_usage_snapshots;
create policy tenant_usage_snapshots_manage_platform
on public.tenant_usage_snapshots
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin())
with check (public.is_platform_owner() or public.is_platform_admin());

comment on column public.roles.role_scope is
  'Authorization scope for this role: platform, tenant, hoa, resident, community, or customer.';

comment on table public.customer_accounts is
  'Tenant-owned customer relationship or service account. Supports residential, community, commercial, and roll-off account types.';

comment on table public.service_locations is
  'Physical serviced locations for customer accounts. Active rows are the default subscription capacity metric.';

comment on table public.customer_memberships is
  'User access to customer accounts and optionally specific service locations.';

comment on table public.customer_verifications is
  'Customer signup and verification attempts, including address/email verification and optional strict-mode methods.';

comment on table public.tenant_usage_snapshots is
  'Auditable tenant usage snapshots for capacity-based subscription billing and overage tracking.';

comment on column public.subscription_plans.included_service_location_count is
  'Included active service-location capacity for customer portal plans. Supersedes HOA/resident limits for new pricing.';

comment on column public.subscription_plans.service_location_overage_cents is
  'Monthly overage price per active service location above plan capacity and grace buffer.';

comment on column public.subscription_plans.service_location_grace_percent is
  'Percentage grace buffer above included service-location capacity before overage billing applies.';

commit;
