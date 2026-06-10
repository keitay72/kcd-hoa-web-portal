# invite-admin-user

Secure Supabase Edge Function used by the Admin Web App to invite, resend, and cancel tenant staff and HOA user invitations without exposing the service role key to Flutter.

## Required environment variables

Supabase provides these automatically when deployed from the linked project:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Configure this project-specific value:

- `ADMIN_INVITE_REDIRECT_URL`: Admin web URL users should land on after accepting the invite, for example `http://192.168.0.141:8080/` for local testing.

## Database dependency

Deploy migration `0015_admin_user_invite_lifecycle.sql` before using this function. It creates:

- `public.admin_user_invites`
- invite lifecycle RLS policies
- expanded `profiles.status` values
- `public.sync_admin_invite_acceptances()`

## Invite request body

```json
{
  "action": "invite",
  "email": "leslie@kansascitydisposal.com",
  "first_name": "Leslie",
  "middle_name": null,
  "last_name": "Taylor",
  "phone": "8164064118",
  "role": "tenant_admin",
  "tenant_id": "optional-platform-tenant-uuid",
  "hoa_id": null
}
```

## Resend request body

```json
{
  "action": "resend",
  "invite_id": "admin-user-invite-uuid"
}
```

## Cancel request body

```json
{
  "action": "cancel",
  "invite_id": "admin-user-invite-uuid"
}
```

Accepted roles:

- Tenant staff: `tenant_admin`, `tenant_manager`, `tenant_csr`, `tenant_dispatch`
- HOA users: `hoa_manager`, `hoa_board`, `hoa_resident`

Tenant staff assignments are written to `public.user_platform_roles` during the transition and exposed through `public.user_tenant_roles`.
HOA user assignments are written to `public.user_hoa_memberships`.
Invite lifecycle state is written to `public.admin_user_invites`.

## Deployment

From the `backend` directory:

```bash
npx supabase db push --project-ref jklqrarqnwbthrqfipjo
npx supabase secrets set ADMIN_INVITE_REDIRECT_URL="http://192.168.0.141:8080/" --project-ref jklqrarqnwbthrqfipjo
npx supabase functions deploy invite-admin-user --project-ref jklqrarqnwbthrqfipjo
```

The calling user must be authenticated and assigned an authorized tenant/platform admin role.
