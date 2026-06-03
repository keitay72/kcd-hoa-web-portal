-- =========================================================
-- Migration: 0002_core_tables.sql
-- Purpose: Create Phase 1 core identity, tenant, role, and permission tables
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- KC Disposal is the primary platform tenant. HOAs are modeled separately
-- in later migrations as communities inside this tenant.
create table if not exists public.platform_tenants (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),

  constraint platform_tenants_code_not_blank check (length(trim(code)) > 0),
  constraint platform_tenants_name_not_blank check (length(trim(name)) > 0)
);

create unique index if not exists uq_platform_tenants_single_primary
  on public.platform_tenants(is_primary)
  where is_primary = true;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext unique not null,
  full_name text,
  phone text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_status_valid check (status in ('active', 'disabled')),
  constraint profiles_email_not_blank check (length(trim(email::text)) > 0)
);

create table if not exists public.roles (
  id bigserial primary key,
  code text unique not null,
  name text not null,
  description text,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),

  constraint roles_code_valid check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint roles_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.permissions (
  id bigserial primary key,
  code text unique not null,
  name text not null,
  description text,
  created_at timestamptz not null default now(),

  constraint permissions_code_valid check (code ~ '^[a-z][a-z0-9_.]*$'),
  constraint permissions_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.role_permissions (
  role_id bigint not null references public.roles(id) on delete cascade,
  permission_id bigint not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),

  primary key (role_id, permission_id)
);

create table if not exists public.user_platform_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.platform_tenants(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  created_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,

  primary key (user_id, tenant_id, role_id)
);

comment on table public.platform_tenants is
  'Platform tenant table. KC Disposal is the primary Phase 1 tenant.';

comment on table public.profiles is
  'Application profile table linked one-to-one with Supabase auth.users.';

comment on table public.roles is
  'Role catalog used by RLS helper functions and application authorization.';

comment on table public.permissions is
  'Permission catalog used by application authorization and admin UX.';

comment on table public.role_permissions is
  'Mapping table between role catalog entries and permission catalog entries.';

comment on table public.user_platform_roles is
  'Platform-level role assignments for KC Disposal staff and system administrators.';

commit;
