-- =========================================================
-- Migration: 0040_community_role_display_names.sql
-- Purpose: Update legacy HOA role display names for the customer portal model
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

update public.roles
set
  name = 'Community Board Member',
  description = 'Community board member with community-scoped portal access.'
where code = 'hoa_board';

update public.roles
set
  name = 'Community Manager',
  description = 'Community manager with community-scoped management access.'
where code = 'hoa_manager';

update public.roles
set
  name = 'Customer',
  description = 'Verified customer with customer portal access.'
where code = 'hoa_resident';

commit;
