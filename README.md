# HOA Portal SaaS Platform

Multi-tenant HOA portal platform for waste-management companies that provide residential HOA services.

KC Disposal is the first tenant/customer implementation. The product is being refactored into a SaaS platform that can support additional waste-management companies such as Mountain High Disposal and future subscribers without cloning the application or database.

## Product Direction

The platform is designed around four scopes:

- Platform: SaaS owner/operator team that manages tenants, subscriptions, global support, pricing, and platform operations.
- Tenant: Waste-management company subscriber, such as KC Disposal.
- HOA: HOA communities managed under a tenant.
- Resident: Verified resident users associated with HOA addresses.

The immediate priority is the Flutter Web Admin App in `apps/admin_web_app` and the Supabase backend in `backend/supabase`.

The resident mobile app remains planned, but `apps/mobile_app` is deferred until the Admin Web App and SaaS tenant foundation are stable.

## Current Stack

- Flutter Web
- Riverpod
- GoRouter
- Supabase Flutter
- Supabase Auth
- Supabase PostgreSQL
- Supabase Row Level Security
- Supabase Storage
- Supabase Realtime
- Supabase Edge Functions
- Stripe-ready billing integration placeholders

## Current Status

Implemented or in progress:

- Admin authentication and Supabase session handling
- Persistent admin navigation shell
- Responsive/collapsible sidebar navigation
- Signed-in user and role display
- Tooltip support for clipped role text
- Role-Based Access Control UI integration
- Permission-aware navigation visibility
- Protected admin routes
- Unauthorized page
- HOA Management
- Address Registry Management
- Bulk address CSV import
- Activation Code Management
- Resident Verification Management
- Document Management with Supabase Storage uploads and signed downloads
- Announcement Management
- Service Schedule Management with HOA-wide defaults and optional address overrides
- Ticket Operations Management
- Dispatch Workflow Management
- CSR and Dispatch queue dashboards
- User and Role Management
- Invite lifecycle handling for admin users
- Analytics and Operations Dashboard
- Platform Tenant Management
- Tenant commercial settings
- Subscription plan catalog foundations
- Stripe checkout/webhook placeholder functions
- Tenant onboarding workflow

Reserved or planned:

- Audit Log Viewer UI
- Production Stripe activation after account credentials are available
- Tenant email provider configuration workflow
- Tenant SMS/Twilio add-on workflow
- Resident Portal/mobile implementation

## Repository Layout

- `apps/admin_web_app`: Flutter Web admin portal currently under active development.
- `apps/mobile_app`: Deferred resident mobile app skeleton.
- `backend/supabase`: Supabase migrations, Edge Functions, RLS policies, storage policies, and tests.
- `backend/supabase/functions`: Supabase Edge Functions.
- `backend/supabase/migrations`: Versioned database migrations.
- `backend/supabase/tests`: RLS and migration test scripts.
- `docs`: Architecture, ADRs, billing setup, and project documentation.
- `docs/adr`: Architecture decision records.
- `docs/billing`: Stripe/billing setup notes.
- `infra`: Deployment and environment configuration placeholders.
- `packages`: Shared Dart packages and models.
- `scripts`: Local development and database helper scripts.

## Admin Web App Structure

The Admin Web App uses feature-first organization with a lightweight clean architecture pattern.

Common structure inside features:

- `domain`: Domain models and input objects.
- `data`: DTOs and Supabase repositories.
- `presentation`: Pages, dialogs, widgets, and Riverpod providers.

Important app folders:

- `lib/app`: Bootstrap, app widget, router, and navigation shell.
- `lib/core/supabase`: Supabase client providers.
- `lib/core/rbac`: RBAC services, permission rules, role providers, route access utilities, and unauthorized page.
- `lib/features/auth_admin`: Admin sign-in flow.
- `lib/features/hoa_management`: HOA community CRUD workflows.
- `lib/features/address_registry`: HOA address registry and CSV import workflows.
- `lib/features/activation_codes`: Activation code list/detail/generate/reset/revoke/history workflows.
- `lib/features/verification_admin`: Resident verification management workflows.
- `lib/features/documents_cms`: Document CMS and Storage workflows.
- `lib/features/announcements_cms`: Announcement CMS workflows.
- `lib/features/schedules_admin`: HOA-wide service schedules and optional address overrides.
- `lib/features/ticket_operations`: Ticket operations, dispatch, queues, assignment, notes, priority, and metrics.
- `lib/features/user_management`: User invitation, profile, role, HOA scope, tenant scope, and invite lifecycle management.
- `lib/features/analytics_dashboard`: Platform and operational metrics dashboard.
- `lib/features/tenant_management`: SaaS tenant management, commercial settings, subscription assignment, and onboarding workflow.
- `lib/features/commercial_catalog`: Subscription/add-on catalog management foundations.

## SaaS Tenancy Model

The platform is moving from a KC-only architecture to a true multi-tenant SaaS model.

Recommended hierarchy:

- Platform owns the SaaS product and manages tenant subscribers.
- Tenant represents a waste-management company subscriber.
- HOA communities belong to exactly one tenant.
- HOA addresses belong to HOA communities.
- Residents verify against tenant-owned HOA addresses.
- Tenant staff can operate only within their assigned tenant scope.
- HOA users can operate only within their HOA scope.

Key tables involved:

- `platform_tenants`
- `tenant_settings`
- `tenant_email_settings`
- `tenant_sms_settings`
- `tenant_subscriptions`
- `tenant_addons`
- `tenant_billing_contacts`
- `tenant_onboarding_status`
- `hoa_communities`
- `hoa_addresses`
- `profiles`
- `roles`
- `permissions`
- `role_permissions`
- `user_platform_roles`
- `user_global_roles`
- `user_hoa_memberships`
- `user_address_memberships`

## Role Model

Canonical role scopes:

Platform roles:

- `platform_owner`: Full SaaS owner authority.
- `platform_admin`: Platform administrator authority.
- `platform_support`: Cross-tenant support visibility and support actions.
- `platform_sales`: Tenant prospect, onboarding, subscription, and commercial workflow access.

Tenant roles:

- `tenant_admin`: Waste-management company administrator for a tenant.
- `tenant_manager`: Waste-management company management user.
- `tenant_csr`: Tenant customer service user.
- `tenant_dispatch`: Tenant dispatch/operations user.

HOA roles:

- `hoa_manager`: HOA-scoped management user.
- `hoa_board`: HOA-scoped board member user.

Resident role:

- `hoa_resident`: Verified HOA resident.

Deprecated compatibility roles may still exist while the app and database are migrated:

- `sys_admin`
- `mgmt`
- `csr`
- `dispatch`
- `resident`

These should not be used for new role assignments once canonical SaaS role handling is complete.

## RBAC Behavior

The Admin Web App resolves access using Supabase role assignments and permission catalog records.

Source tables:

- `roles`
- `permissions`
- `role_permissions`
- `user_platform_roles`
- `user_global_roles`
- `user_hoa_memberships`

Behavior:

- Navigation items are hidden when the signed-in user lacks access.
- Direct route access is blocked by protected page wrappers.
- Unauthorized users see an unauthorized page instead of requested content.
- Platform/global roles can access platform-wide features.
- Tenant roles are scoped to tenant records.
- HOA roles are scoped to HOA records.
- RLS remains the final enforcement layer in Supabase.

## Supabase Backend

Supabase is the primary backend platform.

Used Supabase services:

- Auth for user identity and sessions.
- PostgreSQL for relational data.
- Row Level Security for tenant/HOA/resident isolation.
- Storage for documents and ticket attachments.
- Realtime-ready schema patterns for future live updates.
- Edge Functions for privileged workflows that must not expose service role keys.

Important migration groups:

- `0001` to `0016`: Original Phase 1 HOA foundation.
- `0017_saas_role_catalog_correction.sql`: SaaS role catalog correction.
- `0018_user_global_roles.sql`: Platform/global role assignment foundation.
- `0019_tenant_role_helpers.sql`: Tenant-aware helper functions.
- `0020_tenant_aware_rls_policies.sql`: Tenant-aware RLS updates.
- `0021_user_tenant_roles_compatibility.sql`: Compatibility bridge for tenant role handling.
- `0022_role_catalog_scope_cleanup.sql`: Role scope cleanup.
- `0023_canonical_role_code_renames.sql`: Canonical role code migration.
- `0024_tenant_commercial_settings.sql`: Commercial/subscription/add-on settings foundation.
- `0025_tenant_onboarding_status.sql`: Tenant onboarding lifecycle tracking.

The deployed Supabase schema is treated as the source of truth for application queries.

## Supabase Edge Functions

Current Edge Functions include:

- `invite-admin-user`: Invites admin users without exposing the service role key to Flutter.
- `verify-address`: Address verification workflow support.
- `verify-activation-code`: Resident activation code verification workflow support.
- `create-tenant-checkout-session`: Stripe-ready placeholder for tenant subscription checkout.
- `sync-tenant-stripe-status`: Stripe-ready placeholder for manual subscription sync.
- `stripe-webhook`: Stripe-ready placeholder webhook endpoint.

Deploy functions from the `backend` directory:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/backend
npx supabase functions deploy invite-admin-user
```

Deploy all relevant functions as needed:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/backend
npx supabase functions deploy create-tenant-checkout-session
npx supabase functions deploy sync-tenant-stripe-status
npx supabase functions deploy stripe-webhook
```

## Billing And Add-Ons

The platform is being prepared for subscription billing.

Planned billing provider:

- Stripe

Reasons Stripe is preferred for this use case:

- Strong subscription billing support.
- Webhook-first subscription lifecycle management.
- Customer portal support.
- Better fit for SaaS recurring plans and add-ons than basic payment collection.

Commercial features being prepared:

- Platform-managed subscription plans.
- Tenant subscription assignments.
- Tenant billing contacts.
- Tenant add-ons.
- SMS/Twilio add-on tracking.
- Tenant email settings for production sender configuration.
- Stripe checkout session creation.
- Stripe webhook status synchronization.

Stripe account credentials are not required for continued non-billing development. Until credentials are configured, Stripe-related functions should fail safely with clear `stripe_not_configured` style responses.

Stripe setup notes live in:

- `docs/billing/stripe-setup.md`

## Tenant Onboarding Workflow

Tenant onboarding is tracked in `tenant_onboarding_status`.

Supported states:

- `not_started`
- `in_progress`
- `blocked`
- `ready_to_launch`
- `launched`
- `cancelled`

Tracked onboarding fields:

- Owner user
- Kickoff completed timestamp
- Launch-ready timestamp
- Launched timestamp
- Blocked reason
- Notes
- Updated-by user

The Tenant Detail page displays onboarding progress based on real configuration data, including:

- Tenant record exists
- Subscription assigned
- Billing contact added
- Support contact configured
- Email sender configured
- SMS decision recorded
- Tenant admin assigned
- First HOA created
- Marked ready to launch

## Service Schedule Model

Service schedules are HOA-wide by default.

Primary schedule fields:

- `hoa_id`
- `address_id`, optional for address-specific overrides
- `service_type`
- `schedule_rule`
- `route_name`
- `effective_date`
- `end_date`
- `status`

Examples:

- Trash = Tuesday
- Recycling = Thursday
- Bulk Pickup = First Saturday

Address-specific schedules should be used only as overrides.

## Ticket Operations Notes

Ticket Operations uses these tables:

- `tickets`
- `ticket_events`
- `ticket_attachments`
- `profiles`
- `hoa_communities`
- `hoa_addresses`
- `user_platform_roles`

Implemented ticket workflows:

- Ticket list and detail views.
- Status changes.
- Staff assignment and reassignment.
- Internal notes through ticket timeline events.
- Priority escalation.
- CSR and dispatch dashboards.
- Queue views.
- SLA indicators.
- Ticket metrics.
- Attachment signed URL viewer.

Security note:

Internal notes are currently represented through tagged ticket events. Before resident-facing ticket timelines are exposed, private internal notes should be moved to a dedicated table or protected with a stricter visibility field and RLS policy.

## Activation Code Security

Activation codes use hash-based verification.

Current model:

- `activation_codes.code_hash` stores the hash.
- Plaintext codes are not stored in the base table.
- Admin visibility for plaintext activation codes requires a separate secure design if needed.

Recommended future production design:

- Keep `code_hash` for verification.
- Store encrypted activation code values only when business requirements demand admin re-display.
- Restrict plaintext viewing to approved roles, such as platform administrators and tenant CSR users.
- Audit every plaintext view, regeneration, resend, and print action.

## Environment Setup

Create local environment files:

```bash
cp .env.example .env
cp apps/admin_web_app/.env.example apps/admin_web_app/.env
```

The Admin Web App reads Supabase config from `apps/admin_web_app/.env`.

Minimum Admin Web App variables:

```bash
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
APP_ENV=dev
```

The root `.env` is for shared/backend/operator variables, including Edge Function and deployment values.

Do not commit real secrets.

## Running The Admin Web App

Run from the Admin Web App directory:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/apps/admin_web_app
flutter pub get
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080 --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

If loading values manually from `apps/admin_web_app/.env`, export them first or pass them directly:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/apps/admin_web_app
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=SUPABASE_URL="https://your-project-ref.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```

For local network access, use the machine IP in the browser, for example:

```text
http://192.168.0.141:8080/
```

## Database Deployment

Run migrations from `backend`:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/backend
npx supabase db push
```

If the project is not linked yet:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/backend
npx supabase link --project-ref your-project-ref
npx supabase db push
```

## Supabase Function Secrets

Set secrets from `backend`:

```bash
cd /Users/keithtaylor/Projects/KCD-HOA-Web-Portal/backend
npx supabase secrets set ADMIN_INVITE_REDIRECT_URL="http://192.168.0.141:8080/"
```

Future Stripe secrets:

```bash
npx supabase secrets set STRIPE_SECRET_KEY="sk_live_or_test_key"
npx supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_value"
npx supabase secrets set STRIPE_CHECKOUT_SUCCESS_URL="https://your-admin-domain/billing/success"
npx supabase secrets set STRIPE_CHECKOUT_CANCEL_URL="https://your-admin-domain/billing/cancel"
```

## Local Tooling Note

This development machine is limited to macOS 13. Some newer Flutter/Dart SDK versions require macOS 14 or later.

If `flutter analyze` or `dart format` cannot run locally because of OS constraints, use:

- Flutter Web compiler output while running the app.
- Supabase migration push output.
- `git diff --check` for whitespace/syntax-adjacent hygiene.
- A compatible Flutter SDK pinned for macOS 13 if deeper local analysis is required.

## Correct Project Directory

Use this corrected project root:

```bash
/Users/keithtaylor/Projects/KCD-HOA-Web-Portal
```

Do not use the old misspelled directory:

```bash
/Users/keithtaylor/Projects/KCD-HOA-Wep-Portal
```

## Development Rules

Current focus:

- Continue development in `apps/admin_web_app`.
- Continue Supabase backend work under `backend/supabase`.
- Do not modify `apps/mobile_app` until the resident/mobile phase resumes.
- Keep KC Disposal as a tenant, not the platform owner/operator concept.
- Prefer tenant-aware data models and RLS for all new work.
- Do not expose Supabase service role keys in Flutter.
- Use Edge Functions for privileged Auth Admin and billing workflows.

## Near-Term Roadmap

Recommended next steps:

1. Finish tenant onboarding UX and launch-readiness checklist.
2. Continue tenant management screens for settings, email, SMS, billing contacts, and add-ons.
3. Finalize canonical role migration in app UI and repositories.
4. Add platform audit visibility for tenant onboarding, billing changes, and role assignments.
5. Configure Stripe once the owner creates the Stripe account.
6. Deploy and verify Stripe webhooks in test mode.
7. Build production tenant email configuration workflow.
8. Build Twilio/SMS add-on configuration workflow.
9. Harden private ticket notes before resident ticket visibility ships.
10. Resume resident portal/mobile development only after the admin SaaS foundation is stable.
