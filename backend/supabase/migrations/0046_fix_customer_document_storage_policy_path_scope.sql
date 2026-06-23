-- =========================================================
-- Migration: 0046_fix_customer_document_storage_policy_path_scope.sql
-- Purpose: Qualify storage object path in customer document Storage policy
-- Environment: Supabase (PostgreSQL)
-- =========================================================

begin;

drop policy if exists hoa_documents_storage_select_authorized on storage.objects;
create policy hoa_documents_storage_select_authorized
on storage.objects
for select
to authenticated
using (
  bucket_id = 'hoa-documents'
  and public.storage_folder_uuid(storage.objects.name, 1) is not null
  and (
    public.can_access_tenant(public.hoa_tenant_id(public.storage_folder_uuid(storage.objects.name, 1)))
    or public.user_has_hoa_role(public.storage_folder_uuid(storage.objects.name, 1), array['hoa_board', 'hoa_manager'])
    or public.user_in_hoa(public.storage_folder_uuid(storage.objects.name, 1))
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
          ca.external_account_ref = public.storage_folder_uuid(storage.objects.name, 1)::text
          or ca.metadata ->> 'legacy_hoa_id' = public.storage_folder_uuid(storage.objects.name, 1)::text
          or sl.metadata ->> 'legacy_hoa_id' = public.storage_folder_uuid(storage.objects.name, 1)::text
        )
    )
  )
);

commit;
