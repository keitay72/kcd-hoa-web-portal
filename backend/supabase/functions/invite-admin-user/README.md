# invite-admin-user

Secure Supabase Edge Function used by the Admin Web App to invite, resend, and cancel tenant staff and HOA user invitations without exposing the service role key to Flutter.

## Required environment variables

Supabase provides these automatically when deployed from the linked project:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Configure this project-specific value:

- `ADMIN_INVITE_REDIRECT_URL`: Admin web invite acceptance URL users should land on after accepting the invite. For local network testing, use `http://192.168.0.141:8080/accept-invite`.

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

## Friendly invite acceptance page

The Admin Web App includes a controlled route at `/accept-invite`.

This route prevents users from seeing Supabase's raw JSON error page when an invite is expired, already used, or malformed. It also clears sensitive session fragments from the browser address bar as soon as the page loads.

Recommended Supabase Auth settings:

```text
Site URL:
http://192.168.0.141:8080

Redirect URLs:
http://192.168.0.141:8080
http://192.168.0.141:8080/
http://192.168.0.141:8080/accept-invite
http://192.168.0.141:8080/#/accept-invite
```

Recommended Supabase Invite User email template:

```html
<h2>You have been invited</h2>
<p>You have been invited to the HOA Portal admin platform.</p>
<p>This invitation link expires and can only be used once.</p>
<p>
  <a href="http://192.168.0.141:8080/#/accept-invite?token_hash={{ .TokenHash }}&type=invite">
    Accept invitation
  </a>
</p>
<p>If you were not expecting this invite, you can ignore this email.</p>
```

Why this template matters:

- It sends users directly to the app-owned `/accept-invite` route first.
- It uses `token_hash` instead of exposing a full Supabase verification URL.
- It lets the Flutter app show friendly expired/invalid messages.
- It avoids putting email, role, tenant, or HOA details in the URL.

Old invites generated before this template change should be cancelled or resent.

## Deployment

From the `backend` directory:

```bash
npx supabase db push
npx supabase secrets set ADMIN_INVITE_REDIRECT_URL="http://192.168.0.141:8080/accept-invite"
npx supabase functions deploy invite-admin-user
```

If you are not linked to the project, link first:

```bash
npx supabase link --project-ref jklqrarqnwbthrqfipjo
```

The calling user must be authenticated and assigned an authorized platform or tenant admin role.
