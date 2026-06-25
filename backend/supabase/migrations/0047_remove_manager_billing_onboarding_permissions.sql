-- Migration: 0047_remove_manager_billing_onboarding_permissions.sql
-- Purpose: Tenant managers should not see billing, subscription, add-on, or launch onboarding data.

with tenant_manager_role as (
  select id
  from public.roles
  where code = 'tenant_manager'
),
restricted_permissions as (
  select id
  from public.permissions
  where code in (
    'billing.read',
    'billing.manage',
    'plans.read',
    'plans.manage',
    'subscriptions.read',
    'subscriptions.manage',
    'addons.read',
    'addons.manage'
  )
)
delete from public.role_permissions role_permission
using tenant_manager_role, restricted_permissions
where role_permission.role_id = tenant_manager_role.id
  and role_permission.permission_id = restricted_permissions.id;
