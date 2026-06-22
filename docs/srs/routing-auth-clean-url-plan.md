# Routing, Auth, And Clean URL Plan

Status: Draft
Last updated: 2026-06-21

## Purpose

Plan the move to one login experience, tenant hostname resolution, and clean path-based URLs without the `#` fragment.

Path URL strategy has been enabled in the Admin Web App. Fragment compatibility remains in place for legacy links and Supabase callback recovery while hosting and redirect settings are finalized.

The PWA/mobile strategy depends on this clean URL and auth model. See `docs/srs/pwa-mobile-strategy.md`.

## Target URL Shape

Legacy Flutter Web routes used hash URLs, for example:

```text
https://example.com/#/admin
```

Target routes should use clean path URLs:

```text
https://portal.com/login
https://portal.com/admin
https://portal.olathewasteinc.com/login
https://portal.olathewasteinc.com/signup
https://portal.olathewasteinc.com/account
```

## Product Principles

- One login page serves all users.
- Tenant portal hostname determines branding and tenant context.
- Login credentials determine identity.
- Roles and memberships determine post-login destination.
- Tenant staff, customer users, community admins, and platform users should not use separate auth systems.
- The `#` fragment should stay out of generated app URLs. Fragment parsing may remain temporarily for legacy links and auth callback compatibility.

## Tenant Hostname Resolution

Tenant portal hostnames should resolve through `tenant_settings.portal_hostname`.

Example:

```text
portal.olathewasteinc.com -> Olathe Disposal tenant
```

Resolution behavior:

1. Read the browser host.
2. Check whether it matches a tenant portal hostname.
3. If matched, load tenant branding and tenant portal settings.
4. If not matched, treat the request as platform/default host.

First-version rule:

- One tenant has one primary portal hostname.
- Do not design for multiple custom domains per tenant yet.

## Route Categories

### Platform Marketing Site

Example:

```text
https://portal.com
```

Purpose:

- Sell the SaaS product.
- Explain features, pricing, onboarding, and contact/demo flow.

This may eventually be a separate marketing app. It does not have to be part of the current Flutter admin/customer portal app.

### Shared Login

Target:

```text
/login
```

Behavior:

- Show platform branding on the platform/default host.
- Show tenant branding on tenant portal hostnames.
- Authenticate with the same Supabase Auth project.
- Route after login based on resolved access contexts.

### Customer Signup

Target:

```text
/signup
```

Behavior:

- Only available when a tenant portal hostname is resolved or a tenant is otherwise selected.
- Uses address + email verification.
- Does not require activation code by default.

### Admin Workspace

Target:

```text
/admin
/admin/tenants
/admin/customers
/admin/service-locations
/admin/tickets
```

Behavior:

- Platform roles see platform administration.
- Tenant roles see tenant-scoped administration.
- Direct route access remains permission protected.

### Customer Portal

Target:

```text
/account
/documents
/schedules
/requests
```

Behavior:

- Customer users see assigned service locations and customer-account contexts.
- Community admins see their community/customer-account workspace.

## Post-Login Routing

After successful auth, resolve all access contexts for the user:

- Platform roles.
- Tenant roles.
- Community/customer account roles.
- Service-location memberships.

Routing priority:

1. If user has exactly one valid context, route directly there.
2. If user has multiple contexts, route to a context selector or use a deterministic default.
3. If user has no active context, route to an account pending/support page.

Suggested priority for deterministic default:

1. Platform admin/support context.
2. Tenant admin/manager context.
3. CSR/dispatch operational context.
4. Community admin context.
5. Customer user context.

## Clean URL Requirements

Flutter Web can use path-based URLs, but the host must support single-page-app rewrites.

Requirement:

- Every application route must serve `index.html` unless it points to a real static asset.

Without this, refreshing a deep link such as `/admin/tenants` can return a 404.

Hosting must support a rewrite equivalent to:

```text
/* -> /index.html
```

## Auth Redirect Requirements

Supabase redirect URLs must be updated when hash routing is removed.

Redirects to review:

- Login callback.
- Password reset.
- Invite acceptance.
- Customer email verification.
- Customer signup completion.
- Tenant portal confirmation links.

Current code has fragment-route handling for `#/...` auth payloads. Clean URL migration should replace this with path/query based callback handling.

Target callback examples:

```text
https://portal.com/auth/callback
https://portal.olathewasteinc.com/auth/callback
https://portal.olathewasteinc.com/signup/complete
https://portal.com/accept-invite
```

## Implementation Phases

### Phase 1: Inventory Current Routes

Document current routes and classify them:

- Platform/admin.
- Tenant admin.
- Customer portal.
- Auth callback.
- Invite acceptance.
- Legacy resident portal.

### Phase 2: Add Tenant Hostname Resolution

Add app-level tenant resolution by hostname before removing `#`.

Reason:

- Login/signup pages need tenant branding and tenant context.
- Address verification should happen inside a resolved tenant.

### Phase 3: Consolidate Login Entry Points

Move toward one `/login` route.

Compatibility:

- Existing `/sign-in` and `/portal/:tenantCode/sign-in` routes may redirect to `/login` during transition.

### Phase 4: Update Auth Callback Flow

Define clean callback routes before changing URL strategy.

Requirements:

- Invite acceptance still works.
- Customer email verification still works.
- Password setup still works.
- Tenant context can be recovered after email verification.

### Phase 5: Switch Flutter To Path URL Strategy

Status: implemented in `apps/admin_web_app/lib/app/admin_bootstrap.dart` with `usePathUrlStrategy()`.

Expected outcome:

- `/#/admin` becomes `/admin`.
- `/#/portal/...` becomes clean tenant portal paths.

### Phase 6: Remove Fragment Compatibility

After clean URLs have been verified in deployed hosting and Supabase redirect settings:

- Remove fragment parsing helpers.
- Remove hash-specific local storage callback workarounds where safe.
- Update docs and Supabase redirect URLs.

## Testing Checklist

Test before and after removing `#`:

- Direct load `/login`.
- Direct load `/admin`.
- Direct load `/admin/tenants`.
- Direct load tenant portal `/signup`.
- Browser refresh on deep admin route.
- Browser refresh on deep customer route.
- Login from platform host.
- Login from tenant portal host.
- Invite acceptance link.
- Customer email verification link.
- Password reset link.
- Sign out.
- Unauthorized route access.
- Unknown tenant hostname.

## Open Questions

- Which host will serve the platform marketing site at launch?
- Will the marketing site and portal app be the same Flutter app initially or separate deployments?
- What hosting provider will serve the Flutter Web app?
- Will tenant custom domains point directly to the app host, or through a proxy/CDN?
- What exact Supabase redirect URLs should be allowed for local, staging, and production?
- Should `/login` on the platform host support tenant staff only, or all users?
- Should customers ever log in through `portal.com`, or only through the tenant's portal hostname?

## Non-Goals

- Do not remove fragment compatibility until deployed hosting rewrites and Supabase auth redirects are verified.
- Do not create separate login pages for different user types.
- Do not design multi-domain tenant support until a real tenant requires it.
