# KC Disposal HOA Web Portal

Phase 1 admin web portal for KC Disposal's HOA resident services platform.

The current build priority is the Flutter Web Admin App in `apps/admin_web_app`. The resident mobile app remains planned, but mobile implementation is deferred until the Admin Web App is operational.

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

## Current Admin Features

Implemented in `apps/admin_web_app`:

- Admin authentication and Supabase session handling
- Permanent admin navigation shell
- Responsive left navigation sidebar
- Collapsible desktop sidebar
- Mobile drawer navigation
- Current signed-in user display
- Current role display from Supabase role assignments
- Role-Based Access Control UI integration
- Permission-based navigation visibility
- Protected admin route wrappers
- Unauthorized access page
- HOA Management
- Address Registry Management
- Bulk address CSV import
- Activation Code Management
- Resident Verification Management
- Document Management with Supabase Storage uploads and signed downloads
- Announcement Management with draft/published/archived workflows
- Service Schedule Management with HOA-wide defaults and optional address overrides
- Ticket Operations Management
- Ticket Dispatch and Workflow Management
- CSR and Dispatch ticket queue dashboards
- Ticket assignment, internal notes, priority changes, workflow automation, metrics, and SLA indicators

Planned Phase 1 admin area with route reserved in the navigation shell:

- Audit Logs

## Repository Layout

- `apps/admin_web_app`: Flutter Web admin portal
- `apps/mobile_app`: Deferred resident mobile app skeleton
- `backend/supabase`: Supabase migrations, RLS policies, storage policies, and tests
- `packages`: Shared Dart packages
- `docs`: Product and engineering docs
- `infra`: Deployment and environment configuration
- `scripts`: Local development and database utility scripts

## Admin Web App Structure

The Admin Web App uses feature-first organization:

- `lib/app`: App bootstrap, router, and admin navigation shell
- `lib/core/supabase`: Supabase client providers
- `lib/core/rbac`: Role service, permission service, access model, providers, route protection, and unauthorized page
- `lib/features/auth_admin`: Admin sign-in flow
- `lib/features/hoa_management`: HOA list/detail/create/edit workflows
- `lib/features/address_registry`: Address list/detail/create/edit/import workflows
- `lib/features/activation_codes`: Activation code list/detail/generate/reset/revoke/history workflows
- `lib/features/verification_admin`: Resident verification list/detail/status workflows
- `lib/features/documents_cms`: Document list/detail/upload/edit/archive/download workflows
- `lib/features/announcements_cms`: Announcement list/detail/create/edit/archive/publish workflows
- `lib/features/schedules_admin`: HOA-wide service schedule and optional address override workflows
- `lib/features/ticket_operations`: Ticket list/detail/status/assignment/priority/notes/queue/workflow workflows

Each implemented feature follows a lightweight clean architecture shape:

- `domain`: Domain models and input objects
- `data`: DTOs and Supabase repositories
- `presentation`: Pages, dialogs, and Riverpod providers

## RBAC Model

The Admin Web App resolves access from the deployed Supabase role and permission catalog.

Source tables:

- `roles`
- `permissions`
- `role_permissions`
- `user_platform_roles`
- `user_hoa_memberships`

Supported Phase 1 admin roles:

- `sys_admin`
- `mgmt`
- `csr`
- `dispatch`
- `hoa_manager`
- `hoa_board`

RBAC behavior:

- Navigation items are hidden when the signed-in user lacks the required permission.
- Direct route access is blocked by protected admin page wrappers.
- Unauthorized users see the Admin Unauthorized page instead of the requested content.
- Platform-wide staff roles are resolved from `user_platform_roles`.
- HOA-scoped roles are resolved from active `user_hoa_memberships` records.
- Permission checks use the seeded `role_permissions` catalog as the source of truth.

## Ticket Operations

Ticket Operations uses the deployed Phase 1 ticket tables:

- `tickets`
- `ticket_events`
- `ticket_attachments`
- `profiles`
- `hoa_communities`
- `hoa_addresses`
- `user_platform_roles`

Implemented workflows:

- Ticket list and detail views
- Status changes
- Staff assignment and reassignment through `ticket_events`
- Internal note entry through the admin timeline
- Priority management and escalation
- CSR queue dashboard
- Dispatch queue dashboard
- Urgent and aging queue views
- SLA state indicators
- Ticket metrics counters
- Workflow automation action
- Attachment signed URL viewer

Current ticket status labels map to the existing database status values. For example, `Open` maps to `triaged`, and `Assigned` maps to `assigned`.

### Internal Notes Security Note

Internal notes are currently stored as tagged `ticket_events` rows for the admin workflow timeline. Current Phase 1 RLS allows users who can read a ticket to read its ticket events. Before resident-facing ticket timelines are exposed, true private internal notes should be moved to a dedicated `ticket_internal_notes` table or protected with a visibility column and stricter RLS.

## Supabase Backend

Phase 1 migrations are located in `backend/supabase/migrations` and include:

- Core tenant/profile/role/permission tables
- HOA communities and HOA addresses
- Resident verification tables
- Activation codes and activation code events
- Announcements, documents, schedules, tickets, attachments, and audit logs
- RLS helper functions
- RLS policies
- Storage policies
- Role/permission seed data
- Development seed data
- HOA-wide service schedule schema migration in `0014_service_schedule_hoa_wide_model.sql`

The deployed schema is treated as the source of truth for Admin Web App queries.

## Service Schedule Model

Service schedules are modeled as HOA-wide defaults first:

- `hoa_id`: HOA community receiving service
- `service_type`: `trash`, `recycling`, `yard_waste`, or `bulk`
- `schedule_rule`: human-readable rule such as `Tuesday`, `Thursday`, or `First Saturday`
- `route_name`: optional KC Disposal route label
- `effective_date`: first date the schedule applies
- `end_date`: optional historical end date
- `status`: `active` or `archived`

Address-specific schedules are optional overrides only. Override rows use the same `service_schedules` table with `address_id` populated. HOA-wide default rows keep `address_id` as `null`.

## Environment Setup

Copy environment examples before running locally:

```bash
cp .env.example .env
cp apps/admin_web_app/.env.example apps/admin_web_app/.env
```

The Admin Web App expects Supabase project values in `apps/admin_web_app/.env`.

## Local Development

From the repo root:

```bash
cd apps/admin_web_app
flutter pub get
flutter run -d chrome
```

Run static analysis when the local Flutter/Dart toolchain supports it:

```bash
flutter analyze
```

Note: this development machine is limited to macOS 13. If the installed Flutter/Dart SDK requires macOS 14, use the running Flutter Web compiler/hot restart output for local compile feedback or pin a compatible Flutter SDK for this hardware.

## Activation Code Security Note

Activation codes are generated client-side for one-time display to authorized KC Disposal staff. Only the SHA-256 hash is stored in `public.activation_codes.code_hash`. The plaintext code is not persisted and is shown only immediately after generation or reset.

## Working Directory Note

Use the corrected project root:

```bash
/Users/keithtaylor/Projects/KCD-HOA-Web-Portal
```

Do not use the old misspelled `KCD-HOA-Wep-Portal` directory.
