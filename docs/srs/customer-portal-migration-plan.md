# Customer Portal Migration Plan

Status: Draft
Last updated: 2026-06-21

## Purpose

Plan the migration from the current HOA-centered schema to the customer portal data model before writing database migrations.

This plan keeps the current app operational while adding generalized customer account and service location tables that can support residential, HOA/community, commercial, and future roll-off customers.

## Guiding Decision

Phase 1 should introduce the generalized customer model without removing legacy HOA tables.

Start with:

- `customer_accounts`
- `service_locations`
- `customer_memberships`
- `customer_verifications`

Defer `service_contexts` until there is a clear implementation need for a separate city, route, or community grouping layer.

## Why This Order

The current system already has useful SaaS infrastructure:

- Tenants
- Tenant settings and portal hostname
- RBAC
- Profiles
- Tickets
- Documents
- Schedules
- Billing/subscription foundations

The risky part is the customer layer. A phased migration lets the product move toward the new model without breaking existing HOA workflows.

## Phase 0: Confirm Product Decisions

Before migration work starts, confirm:

- Active service locations are the primary subscription capacity metric.
- HOA/community is represented as `customer_accounts.account_type = 'community'`.
- Direct residential service can use `account_type = 'residential'`.
- Commercial service can use `account_type = 'commercial'`.
- Roll-off can use `account_type = 'roll_off'` later.
- Activation codes are optional strict-mode verification only.
- One login flow will serve all user types.

## Phase 1: Add Generalized Tables

Add new tables without changing existing app behavior:

- `customer_accounts`
- `service_locations`
- `customer_memberships`
- `customer_verifications`

Initial migration:

- `backend/supabase/migrations/0035_customer_portal_foundation.sql`

Recommended migration behavior:

- Idempotent where practical.
- Enable RLS immediately.
- Start with conservative policies.
- Add indexes for tenant scope, account scope, location lookup, normalized address lookup, and membership lookup.
- Add trigger checks to ensure tenant/account/location relationships match.

## Phase 2: Backfill From HOA Data

Backfill current HOA data into the new model.

Initial migration:

- `backend/supabase/migrations/0036_backfill_customer_portal_from_hoa.sql`

Mapping:

| Source | Target |
|---|---|
| `hoa_communities` | `customer_accounts` with `account_type = 'community'` |
| `hoa_addresses` | `service_locations` |
| `user_hoa_memberships` | `customer_memberships` at account level |
| `user_address_memberships` | `customer_memberships` at service-location level |
| `residency_verifications` | `customer_verifications` |

Backfill notes:

- Preserve source IDs in `metadata` for traceability.
- Use tenant IDs from `hoa_communities.tenant_id`.
- Use HOA code/name as customer account code/name where available.
- Keep existing HOA data authoritative until app workflows move to the new tables.

## Phase 3: Add Compatibility Bridges

Avoid a single large application rewrite.

Initial app-side foundation:

- `apps/admin_web_app/lib/features/customer_accounts/domain/customer_account.dart`
- `apps/admin_web_app/lib/features/customer_accounts/domain/service_location.dart`
- `apps/admin_web_app/lib/features/customer_accounts/data/customer_account_repository.dart`

Possible bridge approaches:

- Add views that expose customer data in HOA-shaped forms for read-only compatibility.
- Add bridge columns such as `customer_account_id` to legacy tables where needed.
- Add repository-level compatibility mapping in Flutter while both models coexist.

Preferred approach:

- Use explicit backfilled IDs and repository updates rather than complex polymorphic database views unless a view clearly reduces risk.

## Phase 4: Generalize Dependent Tables

Update existing feature tables one at a time.

### Documents

Current:

```text
documents.hoa_id
```

Target:

```text
documents.tenant_id
documents.customer_account_id
documents.service_location_id
documents.scope_type
```

Recommended first move:

- Add new nullable scope columns.
- Backfill from `hoa_id`.
- Keep `hoa_id` until all app reads/writes move.

### Announcements

Follow the same scope strategy as documents.

### Service Schedules

Current:

```text
service_schedules.hoa_id
service_schedules.address_id
```

Target:

```text
service_schedules.tenant_id
service_schedules.customer_account_id
service_schedules.service_location_id
```

Preserve:

- Account-level defaults.
- Location-level overrides.

### Tickets

Current:

```text
tickets.hoa_id
tickets.address_id
```

Target:

```text
tickets.tenant_id
tickets.customer_account_id
tickets.service_location_id
```

Preserve:

- Ticket events.
- Ticket attachments.
- CSR queue.
- Customer-service queue and ticket board/list views.
- Priority/status model.

## Phase 5: Update Signup Flow

Continue replacing legacy activation-code signup paths with address match plus email verification.

Target flow:

1. Resolve tenant from portal hostname.
2. Normalize submitted address.
3. Match active `service_locations` by tenant and normalized address.
4. Create `customer_verifications` row.
5. Send verification email.
6. Complete auth/profile setup after email verification.
7. Create active `customer_memberships` row.

Compatibility:

- Existing activation-code tables/columns may remain only for migration compatibility and historical reporting.
- New signup should use address match plus email verification.

## Phase 6: Update Roles

Add target roles:

- `community_admin`
- `customer_user`

Keep compatibility roles:

- `hoa_manager`
- `hoa_board`
- `hoa_resident`

Migration guidance:

- Map `hoa_board` and `hoa_manager` users to `community_admin` in new customer memberships unless distinct permissions are later required.
- Map address-level resident memberships to location-scoped `customer_user` memberships.
- Do not map `hoa_resident` to account-level access unless a resident should see every service location in that customer account.
- Keep old role assignments until legacy workflows no longer depend on them.

## Phase 7: Update Subscription Capacity

Deprecate plan limits based on HOA/resident counts.

Current:

- `subscription_plans.included_hoa_count`
- `subscription_plans.included_resident_count`

Target:

- `subscription_plans.included_service_location_count`
- Optional `subscription_plans.service_location_overage_cents`
- Optional usage snapshot table for auditable billing counts.

Initial catalog migration:

- `backend/supabase/migrations/0037_customer_portal_subscription_catalog.sql`

Recommended new table:

```text
tenant_usage_snapshots
```

Use snapshots to track:

- Active customer accounts.
- Active service locations.
- Active customer users.
- Plan limit.
- Grace limit.
- Billable overage count.

## Phase 8: Move App Workflows Gradually

Suggested workflow order:

1. Tenant portal hostname resolution.
2. One login routing/context resolution.
3. Customer signup/address verification.
4. Customer account/service location admin views.
5. Documents.
6. Service schedules.
7. Tickets/service requests.
8. Announcements.
9. Billing usage and overages.

## Validation Checklist

Before each phase is considered complete:

- Existing HOA workflows still load.
- Tenant isolation still holds.
- RLS tests cover the new tables.
- Backfilled row counts match expected source counts.
- A known HOA maps to one customer account.
- A known HOA address maps to one service location.
- A known resident maps to one customer membership.
- A tenant staff user cannot read another tenant's customer data.
- A customer user cannot read unassigned locations.

## Rollback Strategy

Early phases should be additive.

Rollback expectation:

- Disable app usage of new tables.
- Keep legacy HOA tables untouched.
- Drop or ignore new additive structures only if no production writes depend on them.

Avoid destructive migrations until:

- New model has been validated in production-like data.
- App workflows no longer depend on old tables.
- Backups and rollback procedures are tested.

## Open Questions

- Should documents and announcements share one scoped content model?
- Should usage overages be billed monthly from live counts or usage snapshots?
- How long should compatibility roles remain visible in admin UI?
- When can legacy activation-code tables/columns be removed after beta data cleanup?
