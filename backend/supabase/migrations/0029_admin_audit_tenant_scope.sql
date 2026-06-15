-- =========================================================
-- Migration: 0029_admin_audit_tenant_scope.sql
-- Purpose: Add tenant scope to admin audit logs for SaaS tenant operations
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.admin_audit_logs
  add column if not exists tenant_id uuid references public.platform_tenants(id) on delete set null;

create index if not exists idx_admin_audit_logs_tenant_created
  on public.admin_audit_logs(tenant_id, created_at desc);

comment on column public.admin_audit_logs.tenant_id is
  'Optional tenant scope for SaaS tenant-level audit events.';

drop policy if exists admin_audit_logs_select_staff on public.admin_audit_logs;
create policy admin_audit_logs_select_staff
on public.admin_audit_logs
for select
to authenticated
using (
  public.is_platform_operator()
  or (
    tenant_id is not null
    and public.can_access_tenant(tenant_id)
  )
  or (
    hoa_id is not null
    and public.can_access_tenant(public.hoa_tenant_id(hoa_id))
  )
);

drop policy if exists admin_audit_logs_insert_staff on public.admin_audit_logs;
create policy admin_audit_logs_insert_staff
on public.admin_audit_logs
for insert
to authenticated
with check (
  public.is_platform_operator()
  or (
    tenant_id is not null
    and public.can_operate_tenant(tenant_id)
  )
  or (
    hoa_id is not null
    and public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  )
);

commit;
