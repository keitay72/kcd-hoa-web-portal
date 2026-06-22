-- =========================================================
-- Migration: 0038_public_api_role_grants.sql
-- Purpose: Grant API roles table access so RLS and service-role functions work
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on all tables in schema public
  to authenticated;

grant select, insert, update, delete on all tables in schema public
  to service_role;

grant usage, select on all sequences in schema public
  to authenticated, service_role;

grant execute on all functions in schema public
  to authenticated, service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;

alter default privileges in schema public
  grant usage, select on sequences to authenticated, service_role;

alter default privileges in schema public
  grant execute on functions to authenticated, service_role;

commit;
