# invite-admin-user

Secure Supabase Edge Function used by the Admin Web App to invite KC Disposal staff and HOA users without exposing the service role key to Flutter.

## Required environment variables

Supabase provides these automatically when deployed from the linked project:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Configure this project-specific value:

- `ADMIN_INVITE_REDIRECT_URL`: Admin web URL users should land on after accepting the invite, for example `https://admin.kcdisposal.com/auth/callback`.

## Request body

```json
{
  "email": "leslie@kansascitydisposal.com",
  "first_name": "Leslie",
  "middle_name": null,
  "last_name": "Taylor",
  "phone": "8164064118",
  "role": "sys_admin",
  "tenant_id": "optional-platform-tenant-uuid",
  "hoa_id": null
}
```

Accepted roles:

- KC staff: `sys_admin`, `mgmt`, `csr`, `dispatch`
- HOA users: `hoa_manager`, `hoa_board`, `resident`

KC staff assignments are written to `public.user_platform_roles`.
HOA user assignments are written to `public.user_hoa_memberships`.

## Deployment

```bash
supabase functions deploy invite-admin-user
supabase secrets set ADMIN_INVITE_REDIRECT_URL="https://your-admin-domain.example/auth/callback"
```

The calling user must be authenticated and assigned the `sys_admin` platform role.
