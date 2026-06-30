# Waste Hauler Customer Portal SaaS

Multi-tenant customer portal platform for waste-management companies.

The product is a SaaS platform sold to trash companies around the country so they can offer a branded customer portal to residential, HOA/community, commercial, and future roll-off customers without cloning the application or database.

KC Disposal and Mountain High Disposal are expected to be the first tenant/customer implementations. Each subscribed trash company is a tenant of the SaaS platform.

## Product Direction

The platform is being repositioned from an HOA portal into a white-label customer portal for waste haulers.

The target product has two public surfaces:

- Platform marketing site: the SaaS sales website, for example `portal.com`.
- Tenant customer portal: the branded portal for each trash company, for example `portal.olathewasteinc.com`.

The platform is designed around these scopes:

- Platform: SaaS owner/operator team that manages tenants, subscriptions, global support, pricing, and platform operations.
- Tenant: Waste-management company subscriber, such as KC Disposal, Mountain High Disposal, or Olathe Disposal.
- Customer account or service context: a tenant-owned account, HOA/community, city/service area, commercial account, roll-off account, or other grouping that controls what portal users see.
- Service location: an address or serviced location associated with a customer account/context.
- Customer user: a person who signs in through the shared login system and sees only the tenant/account/location contexts their roles and memberships allow.

The immediate priority is the Flutter Web Admin App in `apps/admin_web_app` and the Supabase backend in `backend/supabase`, with new work aligned to the broader customer portal model.

The native mobile app remains deferred. The near-term mobile strategy is a responsive web portal with PWA support; do not expand `apps/mobile_app` until the web/PWA portal is stable.

## Current Product Decision

See `docs/adr/0002-customer-portal-saas-product-direction.md`.

This ADR supersedes the HOA-centered product direction in `docs/adr/0001-saas-foundation-correction-plan.md`. ADR 0001 remains useful for historical context and for the tenant/RBAC/billing foundation, but new product work should follow ADR 0002.

Supporting planning docs:

- `docs/prd/customer-portal-domain-model.md`
- `docs/srs/customer-portal-data-model.md`
- `docs/srs/customer-portal-migration-plan.md`
- `docs/srs/routing-auth-clean-url-plan.md`
- `docs/srs/pwa-mobile-strategy.md`
- `docs/srs/ui-ux-redesign-plan.md`

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
- Consolidated Customers workspace for residential, commercial, and roll-off customer setup
- Residential city/community context tabs
- Service-address registry and address detail panel
- Bulk address CSV import
- Customer self-registration with service-address match plus email verification
- Legacy activation-code compatibility reporting kept only for migration/strict-mode visibility
- Document Management with Supabase Storage uploads and signed downloads
- Announcement Management
- Service Schedule Management with customer account, city, community, and service-location scopes
- Ticket Operations Management with CSR-focused queues, board/list views, detail workflows, notes, attachments, SLA, and status history
- Customer portal home with documents, schedules, announcements, contacts, service issues, status badges, and photo attachments
- Customer-service queue dashboards
- Ticket board and list views
- User and Role Management
- Invite lifecycle handling for admin users
- Invite acceptance and password setup flow
- Analytics and Operations Dashboard
- Platform Tenant Management
- Tenant commercial settings
- Subscription plan catalog foundations
- Stripe checkout/webhook placeholder functions
- Tenant onboarding workflow
- Tenant launch-readiness guardrails
- Audit Log Viewer UI

Reserved or planned:
- Production Stripe activation after account credentials are available
- Tenant email provider configuration workflow
- Tenant SMS/Twilio add-on workflow
- Customer portal PWA hardening and mobile polish

## Repository Layout

- `apps/admin_web_app`: Flutter Web admin portal currently under active development.
- `apps/mobile_app`: Deferred native mobile app skeleton. The current mobile strategy is to harden the customer portal as a PWA first.
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
- `lib/features/hoa_management`: Community/customer-account management workflows. The folder name is legacy while the product moves from HOA-first to customer-portal SaaS.
- `lib/features/address_registry`: Service-location registry and CSV import workflows. The folder name is legacy while the UI moves toward service locations.
- `lib/features/verification_admin`: Legacy verification and strict-mode compatibility workflows. The default customer signup flow is service-address match plus email verification.
- `lib/features/documents_cms`: Document CMS and Storage workflows.
- `lib/features/announcements_cms`: Announcement CMS workflows.
- `lib/features/schedules_admin`: Service schedules at customer-account, community, and service-location scopes.
- `lib/features/ticket_operations`: Ticket operations, customer-service queues, ticket board/list views, assignment, notes, priority, SLA, attachments, and metrics.
- `lib/features/user_management`: User invitation, profile, platform/tenant/community roles, tenant scope, invite lifecycle, deactivation/reactivation, and password workflows.
- `lib/features/analytics_dashboard`: Platform and operational metrics dashboard.
- `lib/features/audit_logs`: Admin audit log viewer with actor, scope, action, entity, and JSON change details. Tenant and user-management workflows write audit events for profile changes, role assignment/removal, tenant settings, onboarding, billing contacts, subscriptions, add-ons, and Stripe action requests.
- `lib/features/tenant_management`: SaaS tenant management, commercial settings, subscription assignment, and onboarding workflow.
- `lib/features/commercial_catalog`: Subscription/add-on catalog management foundations.

## SaaS Tenancy Model

The platform is moving from a KC-only HOA architecture to a true multi-tenant customer portal SaaS model.

Recommended hierarchy:

- Platform owns the SaaS product and manages tenant subscribers.
- Tenant represents a waste-management company subscriber.
- Customer accounts, service contexts, and service locations belong to exactly one tenant.
- HOA/community records are one supported customer/service context type, not the center of the product.
- Residential service locations can resolve to a city context or a community/HOA context so non-HOA customers still receive city-specific documents, rules, schedules, and announcements.
- Customers verify against tenant-owned service locations.
- Tenant staff can operate only within their assigned tenant scope.
- Community/customer users can operate only within their assigned customer account, service context, or service location scope.

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

Current implementation note:

The deployed schema still uses HOA-centered tables such as `hoa_communities`, `hoa_addresses`, `user_hoa_memberships`, and `user_address_memberships`. These are legacy/current implementation names. New design work should introduce or migrate toward customer-account/service-location language instead of expanding the HOA model.

## Role Model

Canonical role scopes:

Platform roles:

- `platform_owner`: Full SaaS owner authority.
- `platform_admin`: Platform administrator authority.
- `platform_support`: Cross-tenant support visibility and support actions.
- `platform_sales`: Tenant prospect, onboarding, subscription, and commercial workflow access.

Tenant roles:

- `tenant_owner`: Waste-hauler tenant owner with top-level tenant authority for one tenant.
- `tenant_admin`: Waste-management company administrator for a tenant.
- `tenant_manager`: Waste-management company management user.
- `tenant_csr`: Tenant customer service user.

Community roles:

- `community_admin`: Target future role for HOA board members, property managers, or community-level customer admins.
- `hoa_board`: Existing compatibility role for HOA-scoped board access.
- `hoa_manager`: Existing compatibility role. Avoid adding new workflows that depend on a separate HOA manager role unless it has distinct permissions.

Customer role:

- `customer_user`: Target future role for residential, HOA/community, commercial, and roll-off portal users.
- `hoa_resident`: Existing compatibility role for verified HOA residents.

Deprecated compatibility roles may still exist in historical data and compatibility migrations:

- `sys_admin`
- `mgmt`
- `csr`
- `dispatch`
- `tenant_dispatch`
- `resident`

These should not be used for new role assignments. Active Admin Web App flows and Edge Function authorization should use the canonical SaaS roles above.

`tenant_dispatch` is retained for historical migrations and compatibility only. New invite flows should not expose dispatch unless routing or dispatch operations are reintroduced as an explicit product requirement.

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
- Community/customer roles are scoped to account, service context, or service location records.
- RLS remains the final enforcement layer in Supabase.

## Supabase Backend

Supabase is the primary backend platform.

Used Supabase services:

- Auth for user identity and sessions.
- PostgreSQL for relational data.
- Row Level Security for platform, tenant, customer account, community, city/service context, and service-location isolation.
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
- `0026_admin_invite_platform_role_access.sql`: Invite lifecycle access for canonical platform roles.
- `0027_invite_acceptance_self_service.sql`: Self-service invite acceptance tracking.
- `0028_profile_password_setup_tracking.sql`: Profile password setup tracking for invited users.
- `0029_admin_audit_tenant_scope.sql`: Tenant-scoped audit log support.
- `0030_seed_saas_subscription_catalog.sql`: Original SaaS subscription catalog seed.
- `0031_free_beta_subscription_mode.sql`: Free beta subscription mode.
- `0032_tenant_beta_tracking.sql`: Tenant beta tracking fields.
- `0033_resident_activation_code_settings.sql`: Legacy resident activation code settings retained for migration compatibility.
- `0034_submit_resident_service_issue_rpc.sql`: Resident service issue RPC.
- `0035_customer_portal_foundation.sql`: Generalized customer account, service location, membership, verification, and usage snapshot foundation.
- `0036_backfill_customer_portal_from_hoa.sql`: Backfill generalized customer portal tables from current HOA data.
- `0037_customer_portal_subscription_catalog.sql`: Capacity-based Local, Regional, Metro, and Enterprise customer portal plan catalog.

The deployed Supabase schema is treated as the source of truth for application queries.

## Supabase Edge Functions

Current Edge Functions include:

- `invite-admin-user`: Invites admin users without exposing the service role key to Flutter. It records invite lifecycle state and supports pending, accepted, failed, expired, and cancelled invites.
- `verify-address`: Address verification workflow support.
- `create-tenant-checkout-session`: Stripe-ready placeholder for tenant subscription checkout.
- `sync-tenant-stripe-status`: Stripe-ready placeholder for manual subscription sync.
- `stripe-webhook`: Stripe-ready placeholder webhook endpoint.

Deploy functions from the `backend` directory:

```bash
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/backend
npx supabase functions deploy invite-admin-user
```

Deploy all relevant functions as needed:

```bash
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/backend
npx supabase functions deploy create-tenant-checkout-session
npx supabase functions deploy sync-tenant-stripe-status
npx supabase functions deploy stripe-webhook
```

## Billing And Add-Ons

The platform is being prepared for subscription billing. Subscription tiers should control customer/service-location capacity, not core feature access.

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

Target subscription philosophy:

- Every paid tier includes the complete core customer portal feature set.
- Tier differences are based on the number of active customer accounts or service locations loaded into the portal.
- Avoid feature-gated plans for core portal functionality.
- Use add-ons only for real external cost or heavier operational support, such as SMS messaging, custom email sending domains, advanced integrations/API access, premium support, or white-glove onboarding/import.

Target public plan bands:

- Local: up to 10,000 active customers/service locations.
- Regional: up to 30,000 active customers/service locations.
- Metro: up to 75,000 active customers/service locations.
- Enterprise: 75,000+ active customers/service locations, custom pricing.

Target overage policy:

- Include a small grace buffer so tenants are not penalized for minor growth.
- Bill modest per-customer/service-location overages above the grace buffer.
- Require a plan upgrade when usage stays materially above plan capacity for multiple billing cycles.

Stripe account credentials are not required for continued non-billing development. Until credentials are configured, Stripe-related functions should fail safely with clear `stripe_not_configured` style responses.

Stripe setup notes live in:

- `docs/billing/stripe-setup.md`

## Tenant Onboarding Workflow

Tenant onboarding is tracked in `tenant_onboarding_status`. The Tenant Detail page now treats onboarding as an operational checklist instead of a passive status field.

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
- First customer account/service context created
- Marked ready to launch

Checklist items are actionable. Selecting an item opens the relevant workflow, such as subscription assignment, billing contact setup, tenant settings, email settings, SMS settings, tenant admin assignment, customer account/service context creation, or onboarding status updates.

Launch-readiness behavior:

- `ready_to_launch` and `launched` are blocked until required checklist items are complete.
- The onboarding dialog displays the exact blockers preventing launch.
- Launch-ready and launched timestamps are cleared when blockers exist.
- The tenant list and tenant detail data refresh after onboarding actions.

## Service Schedule Model

Service schedules are tenant-scoped and can be narrowed to a customer account, city/service context, community/HOA context, or specific service location.

Target schedule behavior:

- City-scoped residential schedules apply to non-HOA residential addresses in that city.
- Community-scoped residential schedules apply to addresses in that HOA/community.
- Service-location schedules are overrides for a specific address.
- Commercial and roll-off schedules should use the same customer/account and service-location pattern when those account types are built out.

Current implementation still contains legacy `hoa_id` and `address_id` fields. New UI and documentation should describe these as community context and service-location scope rather than treating HOA as the top-level product model.

## Ticket Operations Notes

Ticket Operations uses these tables:

- `tickets`
- `ticket_events`
- `ticket_attachments`
- `profiles`
- `hoa_communities`
- `hoa_addresses`
- `user_platform_roles`

Some current table names remain HOA-centered for compatibility. New ticket workflows should use customer, community, city, and service-location language in the UI.

Implemented ticket workflows:

- Ticket list and detail views.
- Status changes.
- Staff assignment and reassignment.
- Internal notes through ticket timeline events.
- Priority escalation.
- Customer-service queue dashboard.
- Ticket board and list views.
- SLA indicators.
- Ticket metrics.
- Attachment signed URL viewer.

CSR ticket handling is the primary near-term operations workflow. Ticket screens should be optimized for fast triage, glanceable status, customer/address context, inline workflow actions, photo/document attachments, and clear customer-facing updates.

Security note:

Internal notes are currently represented through tagged ticket events. Before resident-facing ticket timelines are exposed, private internal notes should be moved to a dedicated table or protected with a stricter visibility field and RLS policy.

## Customer Signup And Verification

The customer signup flow does not require mailed activation codes.

Target customer signup flow:

1. Customer visits the tenant-branded portal, such as `portal.olathewasteinc.com`.
2. Customer enters service address and email.
3. The system checks whether the service address exists for that tenant.
4. If eligible, the system creates a pending registration and sends a verification email.
5. Customer clicks the verification email.
6. Customer sets up password, name, phone, and profile details.
7. The account becomes active and linked to the verified service location.

Design notes:

- Use one login page for every user type.
- Authentication identifies the user; roles, tenant membership, customer account membership, and service-location membership determine what they can see.
- Email verification proves email ownership. Address matching proves the service location exists in the tenant registry.
- Multiple users may be associated with the same service location.
- Sensitive future features, such as billing or payment history, may require stronger verification.

Activation codes are legacy compatibility data only. New customer signup uses address match plus email verification, and the active portal no longer exposes an activation-code verification flow.

Legacy activation-code model:

- `activation_codes.code_hash` stores the hash.
- Plaintext codes are not stored in the base table.
- Admin visibility for plaintext activation codes requires a separate secure design if needed.

Do not add new activation-code UI without a fresh product decision and security review.

## Admin Invite Acceptance

Admin invitations use Supabase Auth invite links plus the custom Admin Web App acceptance route.

Local invite acceptance URL:

```text
http://127.0.0.1:8080/accept-invite?token_hash={{ .TokenHash }}&type=invite
```

Important behavior:

- Invite links route to `AcceptInvitePage`.
- The app verifies the invite token with Supabase Auth.
- Invited users must create a password before accessing the admin shell.
- Accepted invites update lifecycle state through `mark_current_user_admin_invite_accepted()`.
- The app clears sensitive token fragments from the browser URL after processing.
- Expired or reused invite links show a friendly app page instead of raw Supabase JSON.

Supabase Auth URL configuration should include the local admin URL during development:

```text
http://127.0.0.1:8080/
http://127.0.0.1:8080/accept-invite
```

For LAN device testing, add the machine IP variant as well. For production, replace these with the deployed admin domain.

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
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/apps/admin_web_app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

If loading values manually from `apps/admin_web_app/.env`, export them first or pass them directly:

```bash
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/apps/admin_web_app
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
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
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/backend
npx supabase db push
```

If the project is not linked yet:

```bash
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/backend
npx supabase link --project-ref your-project-ref
npx supabase db push
```

## Supabase Function Secrets

Set secrets from `backend`:

```bash
cd /Users/keithtaylor/Projects/kcd-hoa-web-portal/backend
npx supabase secrets set ADMIN_INVITE_REDIRECT_URL="http://127.0.0.1:8080/accept-invite"
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
/Users/keithtaylor/Projects/kcd-hoa-web-portal
```

Do not use the old misspelled directory:

```bash
/Users/keithtaylor/Projects/KCD-HOA-Wep-Portal
```

## Development Rules

Current focus:

- Continue development in `apps/admin_web_app`.
- Continue Supabase backend work under `backend/supabase`.
- Do not modify `apps/mobile_app` until the responsive web/PWA portal is stable and a native shell is intentionally planned.
- Keep KC Disposal as a tenant, not the platform owner/operator concept.
- Prefer tenant-aware data models and RLS for all new work.
- Prefer customer-account, service-context, and service-location language for new product work.
- Treat HOA/community functionality as one supported customer segment, not the product's top-level identity.
- Do not expose Supabase service role keys in Flutter.
- Use Edge Functions for privileged Auth Admin and billing workflows.

## Near-Term Roadmap

Recommended next steps:

1. Harden CSR ticket workflows: triage queue, ticket detail, status changes, internal notes, customer updates, attachments, and customer-visible status history.
2. Keep customer setup consolidated in the Customers workspace, with Residential, Commercial, and Roll-Off account-type views.
3. Finish residential city/community scoping so non-HOA customers receive city-specific documents, schedules, announcements, and rules.
4. Continue polishing service-address creation and detail views, including ticket history and optional community assignment.
5. Keep activation-code and dispatch features hidden or clearly marked as legacy unless they return through a fresh product decision.
6. Continue PWA routing/install hardening after core customer and CSR flows are stable.
7. Add usage/overage tracking for active customer accounts or service locations.
8. Configure Stripe once the owner creates the Stripe account, then deploy and verify Stripe webhooks in test mode.
9. Prepare the beta data cleanup/import plan before launch.
