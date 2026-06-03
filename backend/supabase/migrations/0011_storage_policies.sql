-- =========================================================
-- Migration: 0011_storage_policies.sql
-- Purpose: Create Phase 1 Supabase Storage buckets and RLS policies
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

insert into storage.buckets (id, name, public)
values
  ('hoa-documents', 'hoa-documents', false),
  ('ticket-attachments', 'ticket-attachments', false)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public;

-- Path conventions:
-- hoa-documents:       {hoa_id}/{document_id}/{filename}
-- ticket-attachments: {hoa_id}/{ticket_id}/{filename}

-- HOA documents
drop policy if exists hoa_documents_storage_select_authorized on storage.objects;
create policy hoa_documents_storage_select_authorized
on storage.objects
for select
to authenticated
using (
  bucket_id = 'hoa-documents'
  and (
    public.is_kcd_staff()
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
    public.is_kcd_staff()
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
  and (
    public.is_kcd_staff()
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
)
with check (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(name, 1) is not null
  and public.storage_folder_uuid(name, 2) is not null
  and (
    public.is_kcd_staff()
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
  and (
    public.is_kcd_staff()
    or public.user_has_hoa_role(public.storage_folder_uuid(name, 1), array['hoa_board', 'hoa_manager'])
  )
);

-- Ticket attachments
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
      and (
        t.requester_user_id = auth.uid()
        or public.user_has_hoa_role(t.hoa_id, array['hoa_board', 'hoa_manager'])
        or public.is_kcd_staff()
      )
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
        or public.is_kcd_staff()
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
  and public.is_kcd_staff()
)
with check (
  bucket_id = 'ticket-attachments'
  and public.is_kcd_staff()
);

drop policy if exists ticket_attachments_storage_delete_staff on storage.objects;
create policy ticket_attachments_storage_delete_staff
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'ticket-attachments'
  and public.is_kcd_staff()
);

commit;
