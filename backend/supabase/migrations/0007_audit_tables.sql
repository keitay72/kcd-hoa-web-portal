-- =========================================================
-- Migration: 0007_audit_tables.sql
-- Purpose: Create Phase 1 admin audit logging table
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  hoa_id uuid references public.hoa_communities(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_json jsonb,
  after_json jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now(),

  constraint admin_audit_logs_action_not_blank check (length(trim(action)) > 0),
  constraint admin_audit_logs_entity_type_not_blank check (length(trim(entity_type)) > 0),
  constraint admin_audit_logs_entity_id_not_blank check (length(trim(entity_id)) > 0)
);

comment on table public.admin_audit_logs is
  'Append-only audit trail for privileged Phase 1 admin and staff operations.';

commit;
