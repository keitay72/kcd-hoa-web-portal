# Auth

The app uses one Supabase Auth identity system for every user type.

Authentication answers who the person is. Role and membership records decide what the person can see after login.

## Login Routing

After sign-in, the app resolves the user's access in this order:

1. Platform roles.
2. Tenant staff roles.
3. Community contact roles.
4. Customer memberships.

There should not be separate login pages for platform staff, tenant staff, community contacts, residential customers, commercial customers, or roll-off customers.

## Customer Self-Registration

Default customer signup uses service address plus email verification:

1. Resolve tenant from the portal path or hostname.
2. Normalize the submitted service address.
3. Match an active service location for that tenant.
4. Create a pending customer verification.
5. Send a verification email.
6. Let the customer complete password, name, and phone after email verification.
7. Create the customer membership.

Activation codes are legacy/strict-mode compatibility only.

## Staff And Community Invites

Platform staff, tenant staff, and community contacts are invited by authorized users through the `invite-admin-user` Edge Function. The function owns service-role writes so the Flutter app never receives the service role key.

Tenant managers may invite customer service users only. Tenant admins and owners can invite broader tenant/community roles. Platform staff invite platform and tenant roles according to permission.

## Password Reset

Password reset links should route through the app-owned reset password page. The app should show friendly expired or missing-token states and allow the user to request a new link.
