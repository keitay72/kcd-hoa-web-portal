-- =========================================================
-- Migration: 0013_seed_dev.sql
-- Purpose: Seed deterministic Phase 1 development fixtures
-- Environment: Supabase (PostgreSQL)
-- =========================================================
-- Note: This seed intentionally avoids auth.users fixtures. Test users should
-- be created in dedicated RLS test scripts or via Supabase Auth flows.

begin;

insert into public.platform_tenants (id, code, name, is_primary)
values (
  '11111111-1111-1111-1111-111111111111',
  'KC_DISPOSAL',
  'KC Disposal',
  true
)
on conflict (code) do update
set
  name = excluded.name,
  is_primary = excluded.is_primary;

insert into public.hoa_communities (id, tenant_id, code, name, status)
values
  (
    '22222222-2222-2222-2222-222222222221',
    '11111111-1111-1111-1111-111111111111',
    'HOA_OAK_MEADOWS',
    'Oak Meadows HOA',
    'active'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'HOA_LAKESIDE',
    'Lakeside HOA',
    'active'
  )
on conflict (code) do update
set
  name = excluded.name,
  status = excluded.status,
  tenant_id = excluded.tenant_id;

insert into public.hoa_addresses (
  id,
  hoa_id,
  line1,
  line2,
  city,
  state,
  postal_code,
  normalized_key,
  is_active
)
values
  (
    '33333333-3333-3333-3333-333333333331',
    '22222222-2222-2222-2222-222222222221',
    '101 Main St',
    null,
    'Kansas City',
    'MO',
    '64101',
    '101MAINST|KANSASCITY|MO|64101',
    true
  ),
  (
    '33333333-3333-3333-3333-333333333332',
    '22222222-2222-2222-2222-222222222221',
    '102 Main St',
    null,
    'Kansas City',
    'MO',
    '64101',
    '102MAINST|KANSASCITY|MO|64101',
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    '201 Lake Dr',
    null,
    'Kansas City',
    'MO',
    '64102',
    '201LAKEDR|KANSASCITY|MO|64102',
    true
  )
on conflict (hoa_id, normalized_key) do update
set
  line1 = excluded.line1,
  line2 = excluded.line2,
  city = excluded.city,
  state = excluded.state,
  postal_code = excluded.postal_code,
  is_active = excluded.is_active;

insert into public.activation_codes (
  id,
  hoa_id,
  address_id,
  code_hash,
  expires_at,
  status
)
values
  (
    '66666666-6666-6666-6666-666666666661',
    '22222222-2222-2222-2222-222222222221',
    '33333333-3333-3333-3333-333333333331',
    md5('OAK-101-DEMO'),
    now() + interval '30 days',
    'active'
  ),
  (
    '66666666-6666-6666-6666-666666666662',
    '22222222-2222-2222-2222-222222222221',
    '33333333-3333-3333-3333-333333333332',
    md5('OAK-102-DEMO'),
    now() + interval '30 days',
    'active'
  ),
  (
    '66666666-6666-6666-6666-666666666663',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    md5('LAKE-201-DEMO'),
    now() + interval '30 days',
    'active'
  )
on conflict (id) do update
set
  code_hash = excluded.code_hash,
  expires_at = excluded.expires_at,
  status = excluded.status;

insert into public.announcements (
  id,
  hoa_id,
  title,
  body,
  publish_at,
  status
)
values
  (
    '77777777-7777-7777-7777-777777777771',
    '22222222-2222-2222-2222-222222222221',
    'Holiday Service Update',
    'Trash pickup will shift by one day during observed holiday weeks.',
    now(),
    'published'
  ),
  (
    '77777777-7777-7777-7777-777777777772',
    '22222222-2222-2222-2222-222222222222',
    'Lakeside Pickup Reminder',
    'Please place carts at the curb by 7:00 AM on scheduled service days.',
    now(),
    'published'
  )
on conflict (id) do update
set
  title = excluded.title,
  body = excluded.body,
  publish_at = excluded.publish_at,
  status = excluded.status;

insert into public.documents (
  id,
  hoa_id,
  title,
  category,
  storage_path,
  mime_type,
  file_size,
  visibility_scope,
  status
)
values
  (
    '88888888-8888-8888-8888-888888888881',
    '22222222-2222-2222-2222-222222222221',
    'Oak Meadows Service Guide',
    'service',
    '22222222-2222-2222-2222-222222222221/88888888-8888-8888-8888-888888888881/service-guide.pdf',
    'application/pdf',
    0,
    'resident',
    'active'
  ),
  (
    '88888888-8888-8888-8888-888888888882',
    '22222222-2222-2222-2222-222222222222',
    'Lakeside Service Guide',
    'service',
    '22222222-2222-2222-2222-222222222222/88888888-8888-8888-8888-888888888882/service-guide.pdf',
    'application/pdf',
    0,
    'resident',
    'active'
  )
on conflict (id) do update
set
  title = excluded.title,
  category = excluded.category,
  storage_path = excluded.storage_path,
  mime_type = excluded.mime_type,
  file_size = excluded.file_size,
  visibility_scope = excluded.visibility_scope,
  status = excluded.status;

insert into public.service_schedules (
  id,
  hoa_id,
  address_id,
  service_type,
  service_day,
  start_date,
  end_date,
  notes
)
values
  (
    '99999999-0000-0000-0000-000000000001',
    '22222222-2222-2222-2222-222222222221',
    null,
    'trash',
    2,
    current_date,
    null,
    'Oak Meadows HOA-wide weekly trash pickup'
  ),
  (
    '99999999-0000-0000-0000-000000000002',
    '22222222-2222-2222-2222-222222222221',
    null,
    'recycling',
    4,
    current_date,
    null,
    'Oak Meadows HOA-wide weekly recycling pickup'
  ),
  (
    '99999999-0000-0000-0000-000000000003',
    '22222222-2222-2222-2222-222222222222',
    null,
    'trash',
    3,
    current_date,
    null,
    'Lakeside HOA-wide weekly trash pickup'
  ),
  (
    '99999999-0000-0000-0000-000000000004',
    '22222222-2222-2222-2222-222222222222',
    null,
    'bulk',
    6,
    current_date,
    null,
    'Lakeside HOA-wide monthly bulk pickup'
  )
on conflict (id) do update
set
  hoa_id = excluded.hoa_id,
  address_id = excluded.address_id,
  service_type = excluded.service_type,
  service_day = excluded.service_day,
  start_date = excluded.start_date,
  end_date = excluded.end_date,
  notes = excluded.notes;

commit;
