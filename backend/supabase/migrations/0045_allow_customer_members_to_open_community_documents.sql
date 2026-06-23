-- =========================================================
-- Migration: 0045_allow_customer_members_to_open_community_documents.sql
-- Purpose: Allow customer portal members to open community document files
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

-- HOA document paths still begin with the legacy community/HOA id:
--   {hoa_id}/{document_id}/{filename}
-- Customer portal residents may now be linked through customer_memberships
-- instead of legacy hoa_address_memberships, so include both models.
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
    or exists (
      select 1
      from public.customer_memberships cm
      join public.customer_accounts ca
        on ca.id = cm.customer_account_id
      left join public.service_locations sl
        on sl.id = cm.service_location_id
      where cm.user_id = auth.uid()
        and cm.status = 'active'
        and ca.status = 'active'
        and (
          ca.external_account_ref = public.storage_folder_uuid(name, 1)::text
          or ca.metadata ->> 'legacy_hoa_id' = public.storage_folder_uuid(name, 1)::text
          or sl.metadata ->> 'legacy_hoa_id' = public.storage_folder_uuid(name, 1)::text
        )
    )
  )
);

commit;
