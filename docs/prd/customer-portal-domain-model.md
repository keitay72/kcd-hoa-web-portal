# Customer Portal Domain Model

Status: Draft
Last updated: 2026-06-21

## Purpose

Define the target product and data model for the waste hauler customer portal before changing the database schema.

This document translates ADR 0002 into implementation-ready domain language. It should be reviewed before writing migrations that replace or generalize the current HOA-centered tables.

## Product Summary

The product is a white-label customer portal SaaS for waste haulers.

The SaaS operator sells subscriptions to trash companies. Each trash company gets a branded portal where its customers can sign up, view service information, access documents, and submit service requests.

Examples:

- Platform marketing site: `portal.com`
- Tenant customer portal: `portal.olathewasteinc.com`

## Core Principles

- One login experience serves every user type.
- Authentication identifies the person.
- Roles and memberships determine what the person can access after login.
- HOA/community support is one customer segment, not the top-level product model.
- Subscription tiers control capacity, not core feature access.
- Activation codes are optional strict-mode verification, not the default signup path.
- New schema work should use customer-account and service-location language rather than expanding HOA-specific concepts.

## Core Domain Terms

### Platform

The SaaS business that owns and operates the product.

Platform users manage tenants, billing, onboarding, support, global configuration, and product operations.

Current table alignment:

- `user_global_roles`
- `roles`
- `permissions`
- `role_permissions`

### Tenant

A waste hauler subscribed to the SaaS product.

Examples:

- KC Disposal
- Mountain High Disposal
- Olathe Disposal

Current table alignment:

- `platform_tenants`
- `tenant_settings`
- `tenant_email_settings`
- `tenant_sms_settings`
- `tenant_subscriptions`
- `tenant_addons`
- `tenant_billing_contacts`
- `tenant_onboarding_status`

Target behavior:

- Each tenant has one primary portal hostname for now.
- Tenant branding is resolved from the portal hostname.
- Tenant staff can access only their tenant unless they also have platform roles.

### Tenant Portal

The branded customer-facing portal for one tenant.

Example:

```text
portal.olathewasteinc.com
```

Current table alignment:

- `tenant_settings.portal_hostname`
- `tenant_settings.logo_url`
- `tenant_settings.primary_color`
- `tenant_settings.secondary_color`
- `tenant_settings.support_email`
- `tenant_settings.support_phone`

Target behavior:

- Requests to a portal hostname resolve to a tenant.
- The login, signup, customer portal, and tenant staff experience are branded from the resolved tenant.
- One tenant should have one configured portal hostname in the first version.

### Customer Account

A tenant-owned customer relationship or service account.

Customer accounts are the commercial/customer-level object that can represent:

- A direct-billed residential customer.
- An HOA/community service relationship.
- A commercial customer.
- A roll-off customer.

Target fields:

- `id`
- `tenant_id`
- `account_number`, optional but useful for imported systems
- `account_type`: `residential`, `community`, `commercial`, `roll_off`
- `name`
- `status`: `active`, `inactive`, `suspended`
- `billing_customer_ref`, optional external system reference
- `metadata`, optional JSON for import-specific or integration-specific fields
- `created_at`
- `updated_at`

Notes:

- HOA/community should be represented as `account_type = community`, not as the universal parent object.
- A residential direct-service account may have a customer name if imported, but many HOA/service-area addresses may start with only an address.
- Commercial accounts may have multiple service locations.
- Roll-off accounts may later have active containers/orders, but those do not need to exist in the first schema pass.

### Service Context

A tenant-owned grouping used to organize service rules, content, or permissions.

Examples:

- City or municipality.
- HOA/community.
- Route group.
- Commercial portfolio.
- Roll-off service grouping.

Target fields:

- `id`
- `tenant_id`
- `customer_account_id`, nullable when the context is tenant/service-area-wide
- `context_type`: `city`, `community`, `route`, `commercial_group`, `roll_off_group`
- `code`
- `name`
- `status`
- `metadata`
- `created_at`
- `updated_at`

Notes:

- This may be a separate table only if needed. If it adds too much complexity, the first migration can model community/city/route attributes directly on customer accounts and service locations.
- The important product decision is that documents, schedules, and announcements may need to attach above a single address.

### Service Location

A physical location where the tenant provides service.

Examples:

- Residential address.
- HOA home address.
- Commercial dumpster location.
- Roll-off delivery/job site.

Target fields:

- `id`
- `tenant_id`
- `customer_account_id`
- `service_context_id`, nullable
- `line1`
- `line2`
- `city`
- `state`
- `postal_code`
- `normalized_key`
- `status`: `active`, `inactive`
- `service_type_flags`, optional or JSON-backed
- `external_location_ref`, optional
- `created_at`
- `updated_at`

Billing metric:

- Active service locations should be the default subscription capacity metric.
- A household with multiple portal users still counts as one service location.
- A commercial account with five serviced locations counts as five service locations unless a future pricing decision says otherwise.

### Customer User

A person who can sign in and access one or more tenant/customer contexts.

Current table alignment:

- `profiles`
- Supabase `auth.users`

Target behavior:

- A user can belong to multiple tenants only if explicitly assigned.
- A user can belong to multiple customer accounts or service locations.
- A user can be both tenant staff and a customer.
- Login is shared across all user types.

### Customer Membership

The relationship between a user and a customer account or service location.

Target fields:

- `id`
- `user_id`
- `tenant_id`
- `customer_account_id`
- `service_location_id`, nullable for account-level users
- `role_code`: usually `customer_user` or `community_admin`
- `status`: `pending`, `active`, `inactive`, `revoked`
- `is_primary_contact`
- `created_by`
- `created_at`
- `updated_at`

Notes:

- Multiple users may belong to the same service location.
- One user may belong to multiple service locations.
- Community admins should be account/context-level, not tied to a single home address.

### Customer Verification

The process that proves a user can claim access to a service location.

Target fields:

- `id`
- `tenant_id`
- `user_id`
- `customer_account_id`
- `service_location_id`
- `email`
- `email_verified`
- `address_matched`
- `verification_method`: `address_email`, `activation_code`, `manual_review`, `account_number`
- `status`: `pending`, `email_sent`, `verified`, `failed`, `expired`, `cancelled`
- `verified_at`
- `expires_at`
- `metadata`
- `created_at`
- `updated_at`

Default method:

```text
address_email
```

Activation codes:

- Optional strict-mode method.
- Not the default.
- Useful only when a tenant requires stronger address possession proof.

### Content

Documents and announcements should be attachable at multiple scopes.

Target content scopes:

- Tenant-wide.
- Customer account.
- Service context.
- Service location.

Examples:

- City-wide holiday schedule document.
- HOA/community service rules.
- Commercial account service agreement.
- Tenant-wide recycling guide.

Current table alignment:

- `documents.hoa_id`
- `announcements.hoa_id`

Target direction:

- Replace required `hoa_id` with scoped ownership fields or a generic content scope model.
- Keep visibility rules role-aware.

### Service Schedule

A service schedule describes expected pickup or service timing.

Target schedule scopes:

- Tenant-wide default.
- Customer account default.
- Service context default.
- Service location override.

Current table alignment:

- `service_schedules.hoa_id`
- `service_schedules.address_id`

Target direction:

- Preserve the useful default-plus-override pattern.
- Generalize HOA-wide defaults into customer account or service context defaults.
- Keep service location overrides.

### Service Request

A customer-submitted or staff-created issue/request.

Current table alignment:

- `tickets`
- `ticket_events`
- `ticket_attachments`

Target fields to preserve:

- Type.
- Priority.
- Status.
- Subject.
- Description.
- Requester.
- Attachments.
- Timeline/events.

Target direction:

- Replace required `hoa_id` with `tenant_id`, `customer_account_id`, and optional `service_location_id`.
- Keep queue operations for CSR and dispatch.
- Add commercial and roll-off request types later without creating separate ticket systems.

## Signup Flow

Default customer signup should use address match plus email verification.

1. Customer visits tenant portal.
2. Customer enters service address and email.
3. System normalizes the address.
4. System checks for an active service location under the resolved tenant.
5. If eligible, system creates or updates a pending verification.
6. System sends a verification email.
7. Customer clicks verification link.
8. Customer sets password, name, phone, and profile details.
9. System creates an active customer membership.
10. Customer lands in the appropriate portal context.

Security and UX requirements:

- Avoid revealing too much about unmatched addresses.
- Rate-limit signup attempts by IP, email, and normalized address.
- Log verification attempts for abuse review.
- Allow multiple verified users per service location.
- Allow manual review as a fallback.

## Role Model

Target roles:

- `platform_owner`
- `platform_admin`
- `platform_support`
- `platform_sales`
- `tenant_admin`
- `tenant_manager`
- `tenant_csr`
- `tenant_dispatch`
- `community_admin`
- `customer_user`

Compatibility roles:

- `hoa_manager`
- `hoa_board`
- `hoa_resident`

Decision:

- Do not preserve separate HOA Manager and HOA Board Member permissions unless the product identifies a real difference.
- New community-level workflows should use `community_admin`.

## Subscription Capacity Model

Subscription tiers should include all core features.

Capacity metric:

```text
active service locations
```

Plan bands:

- Local: up to 10,000 active service locations.
- Regional: up to 30,000 active service locations.
- Metro: up to 75,000 active service locations.
- Enterprise: 75,000+ active service locations.

Overage policy:

- Include a grace buffer.
- Bill modest overages above the buffer.
- Require plan upgrade if overage remains materially above plan capacity for multiple billing cycles.

Future schema implications:

- `subscription_plans.included_hoa_count` should be deprecated or replaced.
- `subscription_plans.included_resident_count` should be deprecated or replaced.
- Add a customer/service-location capacity field.
- Track monthly active service-location usage snapshots.

## Current-To-Target Table Mapping

| Current table | Target concept | Notes |
|---|---|---|
| `platform_tenants` | Tenant | Keep concept. May rename later only if worth the churn. |
| `tenant_settings` | Tenant portal settings | Keep and expand hostname/branding behavior. |
| `hoa_communities` | Customer account or service context | Community/HOA becomes one account/context type. |
| `hoa_addresses` | Service location | Generalize beyond HOA. |
| `user_hoa_memberships` | Customer/community membership | Replace with broader account/context membership. |
| `user_address_memberships` | Customer service-location membership | Replace with broader service-location membership. |
| `residency_verifications` | Customer verification | Replace resident/HOA naming. |
| `activation_codes` | Optional strict verification | Keep only as optional/compatibility path. |
| `documents` | Scoped content | Generalize scope beyond HOA. |
| `announcements` | Scoped content | Generalize scope beyond HOA. |
| `service_schedules` | Scoped schedule | Generalize default-plus-override model. |
| `tickets` | Service request | Generalize required scope beyond HOA. |
| `subscription_plans` | Capacity plans | Replace HOA/resident limits with service-location/customer capacity. |

## Decisions Captured For First Release

- The first generalized schema uses `customer_accounts` plus `service_locations`; `service_contexts` stays deferred until city, route, or area-level workflows require it.
- Subscription capacity counts active service locations by default, while usage snapshots also retain account and user counts for reporting.
- Community admins attach to account-level customer memberships.
- Commercial and roll-off are represented in the data model as account types, but deeper workflows should stay hidden until the residential/community portal is stable.

## Open Questions

- Should city/service-area documents attach to a future `service_context` table or directly to service locations by city/state?
- How much of the old HOA schema should be migrated in place versus bridged with compatibility views?

## Recommended Next Step

Create a technical schema plan in `docs/srs/customer-portal-data-model.md` that chooses the first migration path and defines:

- New tables.
- Compatibility views or bridge columns.
- RLS scope rules.
- Migration phases.
- Backfill strategy from HOA data.
- Application update sequence.
