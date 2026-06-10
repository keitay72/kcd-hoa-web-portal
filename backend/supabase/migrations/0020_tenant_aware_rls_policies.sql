-- =========================================================
-- Migration: 0020_tenant_aware_rls_policies.sql
-- Purpose: Replace KC-specific RLS policy checks with tenant-aware SaaS helpers
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- Refresh ticket visibility helper so ticket/event/storage policies can use
-- tenant-aware staff access while preserving requester and HOA roles.
create or replace function public.can_read_ticket(_ticket_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tickets t
    where t.id = _ticket_id
      and (
        t.requester_user_id = auth.uid()
        or public.user_has_hoa_role(t.hoa_id, array['hoa_board', 'hoa_manager'])
        or public.is_platform_operator()
        or public.is_tenant_staff(public.hoa_tenant_id(t.hoa_id))
      )
  );
$$;

revoke all on function public.can_read_ticket(uuid) from public, anon, authenticated;
grant execute on function public.can_read_ticket(uuid) to authenticated;


create or replace function public.can_operate_tenant(_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_platform_owner()
    or public.is_platform_admin()
    or public.is_tenant_staff(_tenant_id);
$$;

revoke all on function public.can_operate_tenant(uuid) from public, anon, authenticated;
grant execute on function public.can_operate_tenant(uuid) to authenticated;

-- platform_tenants
-- Tenant users only see their own tenant; platform operators see all tenants.
drop policy if exists platform_tenants_select_authenticated on public.platform_tenants;
create policy platform_tenants_select_authenticated
on public.platform_tenants
for select
to authenticated
using (public.can_access_tenant(id));

drop policy if exists platform_tenants_manage_sys_admin on public.platform_tenants;
create policy platform_tenants_manage_sys_admin
on public.platform_tenants
for all
to authenticated
using (public.is_platform_owner() or public.is_platform_admin())
with check (public.is_platform_owner() or public.is_platform_admin());

-- profiles
-- Profiles are tenant-visible through tenant role assignments, HOA memberships,
-- or address memberships. Users always see themselves; platform operators see all.
drop policy if exists profiles_select_self_or_staff on public.profiles;
create policy profiles_select_self_or_staff
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or public.is_platform_operator()
  or exists (
    select 1
    from public.user_platform_roles target_role
    where target_role.user_id = profiles.id
      and public.can_access_tenant(target_role.tenant_id)
  )
  or exists (
    select 1
    from public.user_hoa_memberships target_hoa
    where target_hoa.user_id = profiles.id
      and target_hoa.status = 'active'
      and (
        public.can_access_tenant(public.hoa_tenant_id(target_hoa.hoa_id))
        or public.user_has_hoa_role(target_hoa.hoa_id, array['hoa_board', 'hoa_manager'])
      )
  )
  or exists (
    select 1
    from public.user_address_memberships target_address
    where target_address.user_id = profiles.id
      and target_address.is_current = true
      and public.can_access_tenant(public.hoa_tenant_id(target_address.hoa_id))
  )
);

drop policy if exists profiles_update_self_or_staff on public.profiles;
create policy profiles_update_self_or_staff
on public.profiles
for update
to authenticated
using (
  id = auth.uid()
  or public.is_platform_owner()
  or public.is_platform_admin()
  or exists (
    select 1
    from public.user_platform_roles target_role
    where target_role.user_id = profiles.id
      and public.can_operate_tenant(target_role.tenant_id)
  )
  or exists (
    select 1
    from public.user_hoa_memberships target_hoa
    where target_hoa.user_id = profiles.id
      and target_hoa.status = 'active'
      and public.can_operate_tenant(public.hoa_tenant_id(target_hoa.hoa_id))
  )
)
with check (
  id = auth.uid()
  or public.is_platform_owner()
  or public.is_platform_admin()
  or exists (
    select 1
    from public.user_platform_roles target_role
    where target_role.user_id = profiles.id
      and public.can_operate_tenant(target_role.tenant_id)
  )
  or exists (
    select 1
    from public.user_hoa_memberships target_hoa
    where target_hoa.user_id = profiles.id
      and target_hoa.status = 'active'
      and public.can_operate_tenant(public.hoa_tenant_id(target_hoa.hoa_id))
  )
);

-- roles / permissions / role_permissions
-- Role catalogs remain readable to authenticated users. Mutation moves to true
-- platform/global management with legacy sys_admin bootstrap support.
drop policy if exists roles_manage_sys_admin on public.roles;
create policy roles_manage_sys_admin
on public.roles
for all
to authenticated
using (public.can_manage_global_roles())
with check (public.can_manage_global_roles());

drop policy if exists permissions_manage_sys_admin on public.permissions;
create policy permissions_manage_sys_admin
on public.permissions
for all
to authenticated
using (public.can_manage_global_roles())
with check (public.can_manage_global_roles());

drop policy if exists role_permissions_manage_sys_admin on public.role_permissions;
create policy role_permissions_manage_sys_admin
on public.role_permissions
for all
to authenticated
using (public.can_manage_global_roles())
with check (public.can_manage_global_roles());

-- user_platform_roles (transitional tenant role assignment table)
drop policy if exists user_platform_roles_select_self_or_staff on public.user_platform_roles;
create policy user_platform_roles_select_self_or_staff
on public.user_platform_roles
for select
to authenticated
using (
  user_id = auth.uid()
  or public.can_access_tenant(tenant_id)
);

drop policy if exists user_platform_roles_manage_sys_admin on public.user_platform_roles;
create policy user_platform_roles_manage_sys_admin
on public.user_platform_roles
for all
to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

-- user_hoa_memberships
drop policy if exists user_hoa_memberships_select_scoped on public.user_hoa_memberships;
create policy user_hoa_memberships_select_scoped
on public.user_hoa_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or public.can_access_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

drop policy if exists user_hoa_memberships_manage_staff on public.user_hoa_memberships;
create policy user_hoa_memberships_manage_staff
on public.user_hoa_memberships
for all
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- hoa_communities
drop policy if exists hoa_communities_select_scoped on public.hoa_communities;
create policy hoa_communities_select_scoped
on public.hoa_communities
for select
to authenticated
using (
  public.user_in_hoa(id)
  or public.can_access_tenant(tenant_id)
);

drop policy if exists hoa_communities_manage_staff on public.hoa_communities;
create policy hoa_communities_manage_staff
on public.hoa_communities
for all
to authenticated
using (public.can_operate_tenant(tenant_id))
with check (public.can_operate_tenant(tenant_id));

-- hoa_addresses
drop policy if exists hoa_addresses_select_scoped on public.hoa_addresses;
create policy hoa_addresses_select_scoped
on public.hoa_addresses
for select
to authenticated
using (
  public.user_in_hoa(hoa_id)
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or public.can_access_tenant(public.hoa_tenant_id(hoa_id))
);

drop policy if exists hoa_addresses_manage_staff on public.hoa_addresses;
create policy hoa_addresses_manage_staff
on public.hoa_addresses
for all
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- user_address_memberships
drop policy if exists user_address_memberships_select_scoped on public.user_address_memberships;
create policy user_address_memberships_select_scoped
on public.user_address_memberships
for select
to authenticated
using (
  user_id = auth.uid()
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or public.can_access_tenant(public.hoa_tenant_id(hoa_id))
);

drop policy if exists user_address_memberships_manage_staff on public.user_address_memberships;
create policy user_address_memberships_manage_staff
on public.user_address_memberships
for all
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- residency_verifications
drop policy if exists residency_verifications_select_self_or_staff on public.residency_verifications;
create policy residency_verifications_select_self_or_staff
on public.residency_verifications
for select
to authenticated
using (
  user_id = auth.uid()
  or public.can_access_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

drop policy if exists residency_verifications_update_staff on public.residency_verifications;
create policy residency_verifications_update_staff
on public.residency_verifications
for update
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

drop policy if exists residency_verifications_delete_staff on public.residency_verifications;
create policy residency_verifications_delete_staff
on public.residency_verifications
for delete
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- activation_codes and activation_code_events
drop policy if exists activation_codes_manage_staff on public.activation_codes;
create policy activation_codes_manage_staff
on public.activation_codes
for all
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

drop policy if exists activation_code_events_manage_staff on public.activation_code_events;
create policy activation_code_events_manage_staff
on public.activation_code_events
for all
to authenticated
using (
  exists (
    select 1
    from public.activation_codes ac
    where ac.id = activation_code_events.activation_code_id
      and public.can_operate_tenant(public.hoa_tenant_id(ac.hoa_id))
  )
)
with check (
  exists (
    select 1
    from public.activation_codes ac
    where ac.id = activation_code_events.activation_code_id
      and public.can_operate_tenant(public.hoa_tenant_id(ac.hoa_id))
  )
);

-- announcements
drop policy if exists announcements_select_scoped on public.announcements;
create policy announcements_select_scoped
on public.announcements
for select
to authenticated
using (
  public.can_access_tenant(public.hoa_tenant_id(hoa_id))
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
  public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
)
with check (
  public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

-- documents
drop policy if exists documents_select_scoped on public.documents;
create policy documents_select_scoped
on public.documents
for select
to authenticated
using (
  public.can_access_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
  or (visibility_scope = 'resident' and public.user_in_hoa(hoa_id))
);

drop policy if exists documents_manage_authorized on public.documents;
create policy documents_manage_authorized
on public.documents
for all
to authenticated
using (
  public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
)
with check (
  public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  or public.user_has_hoa_role(hoa_id, array['hoa_board', 'hoa_manager'])
);

-- service_schedules
drop policy if exists service_schedules_select_scoped on public.service_schedules;
create policy service_schedules_select_scoped
on public.service_schedules
for select
to authenticated
using (
  public.user_in_hoa(hoa_id)
  or public.can_access_tenant(public.hoa_tenant_id(hoa_id))
);

drop policy if exists service_schedules_manage_staff on public.service_schedules;
create policy service_schedules_manage_staff
on public.service_schedules
for all
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- tickets
drop policy if exists tickets_select_authorized on public.tickets;
create policy tickets_select_authorized
on public.tickets
for select
to authenticated
using (public.can_read_ticket(id));

drop policy if exists tickets_update_staff on public.tickets;
create policy tickets_update_staff
on public.tickets
for update
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)))
with check (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

drop policy if exists tickets_delete_staff on public.tickets;
create policy tickets_delete_staff
on public.tickets
for delete
to authenticated
using (public.can_operate_tenant(public.hoa_tenant_id(hoa_id)));

-- ticket_events
drop policy if exists ticket_events_insert_staff on public.ticket_events;
create policy ticket_events_insert_staff
on public.ticket_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.tickets t
    where t.id = ticket_events.ticket_id
      and public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
  )
);

-- ticket_attachments
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
        or public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
      )
  )
);

drop policy if exists ticket_attachments_update_staff on public.ticket_attachments;
create policy ticket_attachments_update_staff
on public.ticket_attachments
for update
to authenticated
using (
  exists (
    select 1
    from public.tickets t
    where t.id = ticket_attachments.ticket_id
      and public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
  )
)
with check (
  exists (
    select 1
    from public.tickets t
    where t.id = ticket_attachments.ticket_id
      and public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
  )
);

drop policy if exists ticket_attachments_delete_staff on public.ticket_attachments;
create policy ticket_attachments_delete_staff
on public.ticket_attachments
for delete
to authenticated
using (
  exists (
    select 1
    from public.tickets t
    where t.id = ticket_attachments.ticket_id
      and public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
  )
);

-- admin_audit_logs
drop policy if exists admin_audit_logs_select_staff on public.admin_audit_logs;
create policy admin_audit_logs_select_staff
on public.admin_audit_logs
for select
to authenticated
using (
  public.is_platform_operator()
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
    hoa_id is not null
    and public.can_operate_tenant(public.hoa_tenant_id(hoa_id))
  )
);

-- admin_user_invites
drop policy if exists admin_user_invites_select_sys_admin on public.admin_user_invites;
create policy admin_user_invites_select_sys_admin
on public.admin_user_invites
for select
to authenticated
using (
  public.is_platform_operator()
  or public.can_access_tenant(coalesce(tenant_id, public.hoa_tenant_id(hoa_id)))
);

drop policy if exists admin_user_invites_manage_sys_admin on public.admin_user_invites;
create policy admin_user_invites_manage_sys_admin
on public.admin_user_invites
for all
to authenticated
using (
  public.is_platform_owner()
  or public.is_platform_admin()
  or public.can_manage_tenant(coalesce(tenant_id, public.hoa_tenant_id(hoa_id)))
)
with check (
  public.is_platform_owner()
  or public.is_platform_admin()
  or public.can_manage_tenant(coalesce(tenant_id, public.hoa_tenant_id(hoa_id)))
);

-- Supabase Storage policies
-- HOA documents: path remains {hoa_id}/{document_id}/{filename}.
drop policy if exists hoa_documents_storage_select_authorized on storage.objects;
create policy hoa_documents_storage_select_authorized
on storage.objects
for select
to authenticated
using (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and (
    public.can_access_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
    or public.user_in_hoa(public.storage_folder_uuid(name, 1))
  )
);

drop policy if exists hoa_documents_storage_insert_authorized on storage.objects;
create policy hoa_documents_storage_insert_authorized
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and public.storage_folder_uuid(name, 2) is not null
  and (
    public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
);

drop policy if exists hoa_documents_storage_update_authorized on storage.objects;
create policy hoa_documents_storage_update_authorized
on storage.objects
for update
to authenticated
using (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and (
    public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
)
with check (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and public.storage_folder_uuid(name, 2) is not null
  and (
    public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
);

drop policy if exists hoa_documents_storage_delete_authorized on storage.objects;
create policy hoa_documents_storage_delete_authorized
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and (
    public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
);

-- Ticket attachments: path remains {hoa_id}/{ticket_id}/{filename}.
drop policy if exists ticket_attachments_storage_select_authorized on storage.objects;
create policy ticket_attachments_storage_select_authorized
on storage.objects
for select
to authenticated
using (
  bucket_id = 'ticket-attachments'
  and public.storage_folder_uuid(name, 1) is not null
  and public.storage_folder_uuid(name, 2) is not null
  and exists (
    select 1
    from public.tickets t
    where t.id = public.storage_folder_uuid(name, 2)
      and t.hoa_id = public.storage_folder_uuid(name, 1)
      and public.can_read_ticket(t.id)
  )
);

drop policy if exists ticket_attachments_storage_insert_authorized on storage.objects;
create policy ticket_attachments_storage_insert_authorized
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'ticket-attachments'
  and public.storage_folder_uuid(name, 1) is not null
  and public.storage_folder_uuid(name, 2) is not null
  and exists (
    select 1
    from public.tickets t
    where t.id = public.storage_folder_uuid(name, 2)
      and t.hoa_id = public.storage_folder_uuid(name, 1)
      and (
        t.requester_user_id = auth.uid()
        or public.can_operate_tenant(public.hoa_tenant_id(t.hoa_id))
      )
  )
);

drop policy if exists ticket_attachments_storage_update_staff on storage.objects;
create policy ticket_attachments_storage_update_staff
on storage.objects
for update
to authenticated
using (
  bucket_id = 'ticket-attachments'
  and public.storage_folder_uuid(name, 1) is not null
  and public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
)
with check (
  bucket_id = 'ticket-attachments'
  and public.storage_folder_uuid(name, 1) is not null
  and public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
);

drop policy if exists ticket_attachments_storage_delete_staff on storage.objects;
create policy ticket_attachments_storage_delete_staff
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'ticket-attachments'
  and public.storage_folder_uuid(name, 1) is not null
  and public.can_operate_tenant(public.hoa_tenant_id(public.storage_folder_uuid(name, 1)))
);

comment on function public.can_read_ticket(uuid) is
  'Returns true when the current user can read a ticket as requester, HOA manager/board, platform operator, or tenant staff.';

comment on function public.can_operate_tenant(uuid) is
  'Returns true when the current user can mutate tenant operational data as platform owner/admin or tenant staff.';

commit;
