-- =========================================================
-- Migration: 0008_indexes.sql
-- Purpose: Add Phase 1 indexes and shared updated_at triggers
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_hoa_communities_updated_at on public.hoa_communities;
create trigger trg_hoa_communities_updated_at
before update on public.hoa_communities
for each row execute function public.set_updated_at();

drop trigger if exists trg_hoa_addresses_updated_at on public.hoa_addresses;
create trigger trg_hoa_addresses_updated_at
before update on public.hoa_addresses
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_hoa_memberships_updated_at on public.user_hoa_memberships;
create trigger trg_user_hoa_memberships_updated_at
before update on public.user_hoa_memberships
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_address_memberships_updated_at on public.user_address_memberships;
create trigger trg_user_address_memberships_updated_at
before update on public.user_address_memberships
for each row execute function public.set_updated_at();

drop trigger if exists trg_residency_verifications_updated_at on public.residency_verifications;
create trigger trg_residency_verifications_updated_at
before update on public.residency_verifications
for each row execute function public.set_updated_at();

drop trigger if exists trg_activation_codes_updated_at on public.activation_codes;
create trigger trg_activation_codes_updated_at
before update on public.activation_codes
for each row execute function public.set_updated_at();

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

drop trigger if exists trg_documents_updated_at on public.documents;
create trigger trg_documents_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

drop trigger if exists trg_service_schedules_updated_at on public.service_schedules;
create trigger trg_service_schedules_updated_at
before update on public.service_schedules
for each row execute function public.set_updated_at();

drop trigger if exists trg_tickets_updated_at on public.tickets;
create trigger trg_tickets_updated_at
before update on public.tickets
for each row execute function public.set_updated_at();

-- Core lookup indexes
create index if not exists idx_profiles_email on public.profiles(email);
create index if not exists idx_roles_code on public.roles(code);
create index if not exists idx_permissions_code on public.permissions(code);
create index if not exists idx_user_platform_roles_user on public.user_platform_roles(user_id);
create index if not exists idx_user_platform_roles_tenant on public.user_platform_roles(tenant_id);
create index if not exists idx_user_platform_roles_role on public.user_platform_roles(role_id);

-- HOA and address indexes
create index if not exists idx_hoa_communities_tenant on public.hoa_communities(tenant_id);
create index if not exists idx_hoa_communities_status on public.hoa_communities(status);
create index if not exists idx_hoa_addresses_hoa on public.hoa_addresses(hoa_id);
create index if not exists idx_hoa_addresses_normalized on public.hoa_addresses(normalized_key);
create index if not exists idx_hoa_addresses_active on public.hoa_addresses(hoa_id, is_active);

-- Membership indexes used by RLS helpers
create index if not exists idx_user_hoa_memberships_user on public.user_hoa_memberships(user_id);
create index if not exists idx_user_hoa_memberships_hoa on public.user_hoa_memberships(hoa_id);
create index if not exists idx_user_hoa_memberships_role on public.user_hoa_memberships(role_id);
create index if not exists idx_user_hoa_memberships_active on public.user_hoa_memberships(user_id, hoa_id, status);
create index if not exists idx_user_address_memberships_user_current on public.user_address_memberships(user_id, is_current);
create index if not exists idx_user_address_memberships_hoa_current on public.user_address_memberships(hoa_id, is_current);
create index if not exists idx_user_address_memberships_address_current on public.user_address_memberships(address_id, is_current);

-- Verification indexes
create index if not exists idx_residency_verifications_user on public.residency_verifications(user_id);
create index if not exists idx_residency_verifications_hoa on public.residency_verifications(hoa_id);
create index if not exists idx_residency_verifications_address on public.residency_verifications(address_id);
create index if not exists idx_activation_codes_address_status on public.activation_codes(address_id, status);
create index if not exists idx_activation_codes_hoa_status on public.activation_codes(hoa_id, status);
create index if not exists idx_activation_code_events_code on public.activation_code_events(activation_code_id);

-- Content indexes
create index if not exists idx_announcements_hoa_status_publish
  on public.announcements(hoa_id, status, publish_at);
create index if not exists idx_documents_hoa_status
  on public.documents(hoa_id, status);
create index if not exists idx_documents_storage_path
  on public.documents(storage_path);
create index if not exists idx_service_schedules_hoa
  on public.service_schedules(hoa_id);
create index if not exists idx_service_schedules_address
  on public.service_schedules(address_id);

-- Ticket indexes
create index if not exists idx_tickets_hoa_status_created
  on public.tickets(hoa_id, status, created_at desc);
create index if not exists idx_tickets_requester_created
  on public.tickets(requester_user_id, created_at desc);
create index if not exists idx_tickets_address
  on public.tickets(address_id);
create index if not exists idx_ticket_events_ticket_created
  on public.ticket_events(ticket_id, created_at);
create index if not exists idx_ticket_attachments_ticket
  on public.ticket_attachments(ticket_id);
create index if not exists idx_ticket_attachments_storage_path
  on public.ticket_attachments(storage_path);

-- Audit indexes
create index if not exists idx_admin_audit_logs_created
  on public.admin_audit_logs(created_at desc);
create index if not exists idx_admin_audit_logs_actor_created
  on public.admin_audit_logs(actor_user_id, created_at desc);
create index if not exists idx_admin_audit_logs_hoa_created
  on public.admin_audit_logs(hoa_id, created_at desc);
create index if not exists idx_admin_audit_logs_entity
  on public.admin_audit_logs(entity_type, entity_id);

commit;
