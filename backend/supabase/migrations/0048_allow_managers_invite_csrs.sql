-- Migration: 0048_allow_managers_invite_csrs.sql
-- Purpose: Let tenant managers invite customer service users without granting
-- full role administration.

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code = 'tenant.users.manage'
where r.code = 'tenant_manager'
on conflict (role_id, permission_id) do nothing;
