# Customer Portal Data Model SRS

Status: Draft
Last updated: 2026-06-21

## Purpose

Define the first technical schema direction for moving from the current HOA-centered data model to the customer portal model.

This document should be completed before database migrations are written.

## Inputs

- `docs/adr/0002-customer-portal-saas-product-direction.md`
- `docs/prd/customer-portal-domain-model.md`
- Current Supabase schema and migrations under `backend/supabase/migrations`

## Design Goal

Introduce a generalized customer/service-location model that supports:

- Residential customers.
- HOA/community customers.
- Commercial customers.
- Future roll-off customers.
- One login experience.
- Address + email customer signup.
- Capacity-based subscription tiers.

## Recommended First-Pass Schema

The first generalized schema should prefer a small set of clear tables:

```text
platform_tenants
  customer_accounts
    service_locations
      customer_memberships
  customer_verifications
```

Add `service_contexts` only if the implementation needs a separate grouping layer for city, route, or HOA/community content before the first migration ships.

## Proposed Tables

### `customer_accounts`

Represents a tenant-owned customer relationship or service account.

Recommended columns:

- `id uuid primary key default gen_random_uuid()`
- `tenant_id uuid not null references public.platform_tenants(id)`
- `account_number text`
- `account_type text not null`
- `name text not null`
- `status text not null default 'active'`
- `external_account_ref text`
- `metadata jsonb not null default '{}'::jsonb`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended constraints:

- `account_type in ('residential', 'community', 'commercial', 'roll_off')`
- `status in ('active', 'inactive', 'suspended')`
- Unique account number per tenant when present.

### `service_locations`

Represents a physical serviced location.

Recommended columns:

- `id uuid primary key default gen_random_uuid()`
- `tenant_id uuid not null references public.platform_tenants(id)`
- `customer_account_id uuid not null references public.customer_accounts(id)`
- `line1 text not null`
- `line2 text`
- `city text not null`
- `state text not null`
- `postal_code text not null`
- `normalized_key text not null`
- `status text not null default 'active'`
- `external_location_ref text`
- `metadata jsonb not null default '{}'::jsonb`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended constraints:

- `status in ('active', 'inactive')`
- `state` is two-letter uppercase state code.
- Unique normalized address key per tenant, with a decision still needed on whether uniqueness should be tenant-wide or account-scoped.

### `customer_memberships`

Represents a user's access to a customer account and optionally one service location.

Recommended columns:

- `id uuid primary key default gen_random_uuid()`
- `tenant_id uuid not null references public.platform_tenants(id)`
- `user_id uuid not null references public.profiles(id)`
- `customer_account_id uuid not null references public.customer_accounts(id)`
- `service_location_id uuid references public.service_locations(id)`
- `role_id bigint not null references public.roles(id)`
- `status text not null default 'active'`
- `is_primary_contact boolean not null default false`
- `created_by uuid references public.profiles(id)`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended constraints:

- `status in ('pending', 'active', 'inactive', 'revoked')`
- Prevent duplicate active membership for the same user, account, optional location, and role.
- Enforce that `service_location_id`, when present, belongs to the same `customer_account_id` and `tenant_id`.

### `customer_verifications`

Tracks customer signup and address/email verification.

Recommended columns:

- `id uuid primary key default gen_random_uuid()`
- `tenant_id uuid not null references public.platform_tenants(id)`
- `user_id uuid references public.profiles(id)`
- `email citext not null`
- `customer_account_id uuid references public.customer_accounts(id)`
- `service_location_id uuid references public.service_locations(id)`
- `verification_method text not null default 'address_email'`
- `address_matched boolean not null default false`
- `email_verified boolean not null default false`
- `status text not null default 'pending'`
- `verified_at timestamptz`
- `expires_at timestamptz`
- `metadata jsonb not null default '{}'::jsonb`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Recommended constraints:

- `verification_method in ('address_email', 'activation_code', 'manual_review', 'account_number')`
- `status in ('pending', 'email_sent', 'verified', 'failed', 'expired', 'cancelled')`

## Existing Tables To Generalize

### Documents

Current dependency:

```text
documents.hoa_id
```

Target options:

1. Add scope columns directly:
   - `tenant_id`
   - `customer_account_id`
   - `service_location_id`
   - `scope_type`

2. Create a generic `content_scopes` model.

Recommendation for first pass:

Use direct nullable scope columns unless a generic scope table clearly reduces complexity.

### Announcements

Current dependency:

```text
announcements.hoa_id
```

Recommendation:

Follow the same scoping pattern chosen for documents.

### Service Schedules

Current dependency:

```text
service_schedules.hoa_id
service_schedules.address_id
```

Recommendation:

Preserve the default-plus-override model:

- Tenant/account default schedule.
- Optional service-location override.

### Tickets

Current dependency:

```text
tickets.hoa_id
tickets.address_id
```

Recommendation:

Generalize to:

- `tenant_id`
- `customer_account_id`
- optional `service_location_id`

Keep ticket events and attachments.

## Subscription Plan Changes

Current capacity fields:

- `subscription_plans.included_hoa_count`
- `subscription_plans.included_resident_count`

Target capacity fields:

- `included_service_location_count`
- Optional future `included_customer_account_count`
- Overage fields, such as `service_location_overage_cents`

Usage tracking recommendation:

Create monthly usage snapshots so billing is based on auditable counts rather than live queries alone.

Possible table:

```text
tenant_usage_snapshots
```

Recommended columns:

- `id`
- `tenant_id`
- `period_start`
- `period_end`
- `active_customer_account_count`
- `active_service_location_count`
- `active_customer_user_count`
- `plan_limit`
- `grace_limit`
- `billable_overage_count`
- `created_at`

## Compatibility Strategy

The application currently uses HOA tables broadly. A safe migration should avoid one giant breaking change.

Recommended phase strategy:

1. Add new generalized tables.
2. Backfill `customer_accounts` and `service_locations` from `hoa_communities` and `hoa_addresses`.
3. Backfill `customer_memberships` from `user_hoa_memberships` and `user_address_memberships`.
4. Backfill `customer_verifications` from `residency_verifications`.
5. Add compatibility views or bridge columns if needed.
6. Update repositories/features one workflow at a time.
7. Keep legacy HOA tables read-compatible until the app no longer depends on them.
8. Remove or archive legacy paths only after production data has been validated.

## RLS Direction

RLS should enforce:

- Platform roles can access cross-tenant data according to permission.
- Tenant roles can access records for assigned tenant IDs.
- Customer/community roles can access only assigned customer accounts, service contexts, or service locations.
- Customer users can access only their own memberships, documents, schedules, announcements, and tickets within assigned contexts.

Helper functions should be tenant-aware and customer-scope-aware.

Avoid new helpers named around HOA unless they are compatibility wrappers.

## Signup Implementation Requirements

Customer signup should:

- Resolve tenant from portal hostname.
- Normalize submitted address.
- Match active service location within that tenant.
- Create pending verification.
- Send verification email.
- Complete profile setup after email verification.
- Create active customer membership.

Security requirements:

- Rate-limit lookup attempts.
- Avoid confirming whether an address exists in public error messages.
- Audit successful and failed verification attempts.
- Expire pending verifications.
- Allow manual support review.

## Decisions Captured In Initial Migration

- `service_contexts` is deferred. The first migration uses `customer_accounts` plus `service_locations`.
- `service_locations.normalized_key` is unique within a customer account and indexed tenant-wide for lookup.
- `customer_accounts.name` is nullable so address-only residential imports do not require fabricated customer names.
- Community admins attach to account-level customer memberships with the `community_admin` role.
- Usage snapshots store customer account count, service location count, and customer user count. Active service locations are the default subscription capacity metric.

## Open Technical Decisions

- Should content scoping use nullable foreign keys or a generic polymorphic scope table?
- How long should legacy HOA tables remain authoritative?

## Non-Goals

- Do not implement commercial or roll-off workflows before the generalized residential/community foundation exists.
- Do not create separate auth systems or login pages.
