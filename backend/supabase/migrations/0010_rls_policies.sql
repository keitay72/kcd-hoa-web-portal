-- =========================================================
-- Migration: 0010_rls_policies.sql
-- Purpose: Enable and define Phase 1 Row Level Security policies
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

alter table public.platform_tenants enable row level security;
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_platform_roles enable row level security;
alter table public.user_hoa_memberships enable row level security;
alter table public.hoa_communities enable row level security;
alter table public.hoa_addresses enable row level security;
alter table public.user_address_memberships enable row level security;
alter table public.residency_verifications enable row level security;
alter table public.activation_codes enable row level security;
alter table public.activation_code_events enable row level security;
alter table public.announcements enable row level security;
alter table public.documents enable row level security;
alter table public.service_schedules enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_events enable row level security;
alter table public.ticket_attachments enable row level security;
alter table public.admin_audit_logs enable row level security;

-- platform_tenants
drop policy if exists platform_tenants_select_authenticated on public.platform_tenants;
create policy platform_tenants_select_authenticated
on public.platform_tenants
for select
to authenticated
using (true);

drop policy if exists platform_tenants_manage_sys_admin on public.platform_tenants;
create policy platform_tenants_manage_sys_admin
on public.platform_tenants
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

-- profiles
drop policy if exists profiles_select_self_or_staff on public.profiles;
create policy profiles_select_self_or_staff
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.is_kcd_staff());

drop policy if exists profiles_update_self_or_staff on public.profiles;
create policy profiles_update_self_or_staff
on public.profiles
for update
to authenticated
using (id = auth.uid() or public.is_kcd_staff())
with check (id = auth.uid() or public.is_kcd_staff());

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

-- roles / permissions / role_permissions
drop policy if exists roles_select_authenticated on public.roles;
create policy roles_select_authenticated
on public.roles
for select
to authenticated
using (true);

drop policy if exists roles_manage_sys_admin on public.roles;
create policy roles_manage_sys_admin
on public.roles
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

drop policy if exists permissions_select_authenticated on public.permissions;
create policy permissions_select_authenticated
on public.permissions
for select
to authenticated
using (true);

drop policy if exists permissions_manage_sys_admin on public.permissions;
create policy permissions_manage_sys_admin
on public.permissions
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

drop policy if exists role_permissions_select_authenticated on public.role_permissions;
create policy role_permissions_select_authenticated
on public.role_permissions
for select
to authenticated
using (true);

drop policy if exists role_permissions_manage_sys_admin on public.role_permissions;
create policy role_permissions_manage_sys_admin
on public.role_permissions
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

-- user_platform_roles
drop policy if exists user_platform_roles_select_self_or_staff on public.user_platform_roles;
create policy user_platform_roles_select_self_or_staff
on public.user_platform_roles
for select
to authenticated
using (user_id = auth.uid() or public.is_kcd_staff());

drop policy if exists user_platform_roles_manage_sys_admin on public.user_platform_roles;
create policy user_platform_roles_manage_sys_admin
on public.user_platform_roles
for all
to authenticated
using (public.is_sys_admin())
with check (public.is_sys_admin());

-- user_hoa_memberships
drop policy if exists user_hoa_memberships_select_scoped on public.user_hoa_memberships;
create policy user_hoa_memberships_select_scoped
on public.user_hoa_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

drop policy if exists user_hoa_memberships_manage_staff on public.user_hoa_memberships;
create policy user_hoa_memberships_manage_staff
on public.user_hoa_memberships
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- hoa_communities
drop policy if exists hoa_communities_select_scoped on public.hoa_communities;
create policy hoa_communities_select_scoped
on public.hoa_communities
for select
to authenticated
using (public.user_in_hoa(id) or public.is_kcd_staff());

drop policy if exists hoa_communities_manage_staff on public.hoa_communities;
create policy hoa_communities_manage_staff
on public.hoa_communities
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- hoa_addresses
drop policy if exists hoa_addresses_select_scoped on public.hoa_addresses;
create policy hoa_addresses_select_scoped
on public.hoa_addresses
for select
to authenticated
using (
  public.user_in_hoa(hoa_id)
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or public.is_kcd_staff()
);

drop policy if exists hoa_addresses_manage_staff on public.hoa_addresses;
create policy hoa_addresses_manage_staff
on public.hoa_addresses
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- user_address_memberships
drop policy if exists user_address_memberships_select_scoped on public.user_address_memberships;
create policy user_address_memberships_select_scoped
on public.user_address_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or public.is_kcd_staff()
);

drop policy if exists user_address_memberships_manage_staff on public.user_address_memberships;
create policy user_address_memberships_manage_staff
on public.user_address_memberships
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- residency_verifications
drop policy if exists residency_verifications_select_self_or_staff on public.residency_verifications;
create policy residency_verifications_select_self_or_staff
on public.residency_verifications
for select
to authenticated
using (user_id = auth.uid() or public.is_kcd_staff());

drop policy if exists residency_verifications_insert_pending_self on public.residency_verifications;
create policy residency_verifications_insert_pending_self
on public.residency_verifications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and address_verified = false
  and email_verified = false
  and activation_code_verified = false
  and status = 'pending'
  and verified_at is null
);

drop policy if exists residency_verifications_update_staff on public.residency_verifications;
create policy residency_verifications_update_staff
on public.residency_verifications
for update
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

drop policy if exists residency_verifications_delete_staff on public.residency_verifications;
create policy residency_verifications_delete_staff
on public.residency_verifications
for delete
to authenticated
using (public.is_kcd_staff());

-- activation_codes and activation_code_events
drop policy if exists activation_codes_manage_staff on public.activation_codes;
create policy activation_codes_manage_staff
on public.activation_codes
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

drop policy if exists activation_code_events_manage_staff on public.activation_code_events;
create policy activation_code_events_manage_staff
on public.activation_code_events
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- announcements
drop policy if exists announcements_select_scoped on public.announcements;
create policy announcements_select_scoped
on public.announcements
for select
to authenticated
using (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or (
    public.user_in_hoa(hoa_id)
    and status = 'published'
    and publish_at <= now()
    and (expire_at is null or expire_at > now())
  )
);

drop policy if exists announcements_manage_authorized on public.announcements;
create policy announcements_manage_authorized
on public.announcements
for all
to authenticated
using (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
)
with check (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

-- documents
drop policy if exists documents_select_scoped on public.documents;
create policy documents_select_scoped
on public.documents
for select
to authenticated
using (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or (visibility_scope = 'resident' and public.user_in_hoa(hoa_id))
);

drop policy if exists documents_manage_authorized on public.documents;
create policy documents_manage_authorized
on public.documents
for all
to authenticated
using (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
)
with check (
  public.is_kcd_staff()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

-- service_schedules
drop policy if exists service_schedules_select_scoped on public.service_schedules;
create policy service_schedules_select_scoped
on public.service_schedules
for select
to authenticated
using (public.user_in_hoa(hoa_id) or public.is_kcd_staff());

drop policy if exists service_schedules_manage_staff on public.service_schedules;
create policy service_schedules_manage_staff
on public.service_schedules
for all
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

-- tickets
drop policy if exists tickets_select_authorized on public.tickets;
create policy tickets_select_authorized
on public.tickets
for select
to authenticated
using (
  requester_user_id = auth.uid()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or public.is_kcd_staff()
);

drop policy if exists tickets_insert_requester on public.tickets;
create policy tickets_insert_requester
on public.tickets
for insert
to authenticated
with check (
  requester_user_id = auth.uid()
  and public.user_has_current_address_membership(auth.uid(), hoa_id, address_id)
);

drop policy if exists tickets_update_staff on public.tickets;
create policy tickets_update_staff
on public.tickets
for update
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

drop policy if exists tickets_delete_staff on public.tickets;
create policy tickets_delete_staff
on public.tickets
for delete
to authenticated
using (public.is_kcd_staff());

-- ticket_events
drop policy if exists ticket_events_select_authorized on public.ticket_events;
create policy ticket_events_select_authorized
on public.ticket_events
for select
to authenticated
using (public.can_read_ticket(ticket_id));

drop policy if exists ticket_events_insert_staff on public.ticket_events;
create policy ticket_events_insert_staff
on public.ticket_events
for insert
to authenticated
with check (public.is_kcd_staff());

-- ticket_attachments
drop policy if exists ticket_attachments_select_authorized on public.ticket_attachments;
create policy ticket_attachments_select_authorized
on public.ticket_attachments
for select
to authenticated
using (public.can_read_ticket(ticket_id));

drop policy if exists ticket_attachments_insert_requester_or_staff on public.ticket_attachments;
create policy ticket_attachments_insert_requester_or_staff
on public.ticket_attachments
for insert
to authenticated
with check (
  uploaded_by = auth.uid()
  and exists (
    select 1
    from public.tickets t
    where t.id = ticket_attachments.ticket_id
      and (
        t.requester_user_id = auth.uid()
        or public.is_kcd_staff()
      )
  )
);

drop policy if exists ticket_attachments_update_staff on public.ticket_attachments;
create policy ticket_attachments_update_staff
on public.ticket_attachments
for update
to authenticated
using (public.is_kcd_staff())
with check (public.is_kcd_staff());

drop policy if exists ticket_attachments_delete_staff on public.ticket_attachments;
create policy ticket_attachments_delete_staff
on public.ticket_attachments
for delete
to authenticated
using (public.is_kcd_staff());

-- admin_audit_logs
drop policy if exists admin_audit_logs_select_staff on public.admin_audit_logs;
create policy admin_audit_logs_select_staff
on public.admin_audit_logs
for select
to authenticated
using (public.is_kcd_staff());

drop policy if exists admin_audit_logs_insert_staff on public.admin_audit_logs;
create policy admin_audit_logs_insert_staff
on public.admin_audit_logs
for insert
to authenticated
with check (public.is_kcd_staff());

commit;
