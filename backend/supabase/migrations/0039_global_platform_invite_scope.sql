-- =========================================================
-- Migration: 0039_global_platform_invite_scope.sql
-- Purpose: Allow admin invites for true global platform roles
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.admin_user_invites
  drop constraint if exists admin_user_invites_scope_valid;

alter table public.admin_user_invites
  add constraint admin_user_invites_scope_valid
  check (
    (
      role_code in ('platform_owner', 'platform_admin', 'platform_support', 'platform_sales')
      and tenant_id is null
      and hoa_id is null
    )
    or (
      role_code not in ('platform_owner', 'platform_admin', 'platform_support', 'platform_sales')
      and tenant_id is not null
      and hoa_id is null
    )
    or (
      role_code not in ('platform_owner', 'platform_admin', 'platform_support', 'platform_sales')
      and tenant_id is null
      and hoa_id is not null
    )
  );

commit;
