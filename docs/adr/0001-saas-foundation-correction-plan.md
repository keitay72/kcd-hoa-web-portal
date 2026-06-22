# ADR 0001: SaaS Foundation Correction Plan

Date: 2026-06-10
Status: Proposed
Owner: KC Disposal HOA Portal Project

> Superseded in part by ADR 0002: Customer Portal SaaS Product Direction.
> This ADR remains useful for SaaS tenant isolation, RBAC, billing, and operational foundation work. Where this ADR frames the product as an HOA Portal SaaS, ADR 0002 is the current product direction.

## Decision

Pause net-new feature development and correct the platform foundation before onboarding additional waste-management companies.

The product direction is now a multi-tenant HOA Portal SaaS platform. KC Disposal is tenant 1, not the platform itself.

Target model:

```text
HOA Portal SaaS Platform
  SaaS Operator
    Platform roles
  Waste-management tenants
    KC Disposal
    Mountain High Disposal
    Future subscribed companies
  HOA communities
  Residents
```

This plan keeps the existing application and data model where possible, but corrects naming, role hierarchy, tenant isolation, RLS semantics, and Admin Web App navigation before continuing feature work.

## Why This Matters

There are already multiple waste-management companies interested in paid subscriptions. That changes the project from a single-company internal portal into a SaaS product.

If we continue adding features before correcting tenancy, we risk:

- leaking data across waste-company customers
- hard-coding KC Disposal assumptions deeper into the app
- creating confusing platform vs tenant role semantics
- making future migrations more expensive
- building Admin UI workflows that do not support tenant onboarding
- reducing confidence for paid customers

The current foundation is good, but its terminology and authorization boundaries need to be realigned.

---

# 1. Current-State Assessment

## What Is Already Good

The current system already includes the hard product foundations:

- Supabase Auth
- PostgreSQL schema
- role and permission catalog
- RLS helper functions
- RLS policies
- Storage policies
- Edge Functions
- Admin Web App
- HOA communities
- HOA address registry
- resident verification
- activation codes
- documents
- announcements
- service schedules
- tickets
- admin audit logs
- user invitation lifecycle
- RBAC-aware navigation

These should be retained.

## Current Tenancy Shape

Current table:

```text
platform_tenants
```

Current meaning in code/comments:

```text
KC Disposal is the primary platform tenant.
```

Correct SaaS meaning:

```text
platform_tenants = waste-management company tenants
```

Examples:

```text
KC_DISPOSAL
MOUNTAIN_HIGH_DISPOSAL
FUTURE_CUSTOMER
```

Current table:

```text
hoa_communities
```

This is already correctly scoped to `platform_tenants` through `tenant_id`.

Current table:

```text
user_platform_roles
```

Current practical meaning:

```text
KC Disposal staff roles assigned inside one platform_tenant
```

SaaS-correct meaning should be:

```text
tenant staff roles assigned inside one waste-management tenant
```

Therefore, this table is conceptually misnamed. It should eventually become:

```text
user_tenant_roles
```

## Current Role Catalog

Current roles:

```text
resident
hoa_board
hoa_manager
tenant_csr
tenant_dispatch
mgmt
sys_admin
```

Current concerns:

- `sys_admin` currently means KC Disposal tenant admin, not true SaaS platform admin.
- `mgmt` is abbreviated and tenant-specific.
- `tenant_csr` and `tenant_dispatch` are valid, but should be tenant-scoped.
- `hoa_manager`, `hoa_board`, and `resident` are valid and should remain HOA-scoped.
- There are no true SaaS operator roles yet.

## Current RLS Helper Concerns

Current helper functions include:

```text
auth_role_codes()
has_platform_role()
has_any_platform_role()
is_sys_admin()
is_kcd_staff()
user_in_hoa()
user_has_hoa_role()
user_has_current_address_membership()
can_read_ticket()
```

Main issue:

```text
is_kcd_staff()
```

This hard-codes KC Disposal into the authorization model. In SaaS, this concept should become tenant staff authorization.

Current behavior:

```text
is_kcd_staff() = sys_admin, tenant_csr, tenant_dispatch, mgmt
```

Target behavior:

```text
is_tenant_staff(tenant_id) = tenant_admin, tenant_manager, tenant_csr, tenant_dispatch within that tenant
```

There should also be separate global platform helper functions for SaaS operator roles.

## Current Admin Web App RBAC Concerns

Current Admin Web App services use:

```text
platformRolesForUser()
user_platform_roles
isSystemAdmin => hasRole('sys_admin')
```

This works for KC Disposal, but will be confusing and risky for multi-tenant SaaS.

The app needs to distinguish:

```text
Global platform roles
Tenant roles
HOA roles
Resident roles
```

---

# 2. Target-State Architecture

## Authorization Layers

The target system should have four role layers.

### Layer 1: Platform Roles

These belong to the SaaS operator.

Roles:

```text
platform_owner
platform_admin
platform_support
platform_sales
```

Scope:

```text
Global SaaS platform
```

Stored in future table:

```text
user_global_roles
```

### Layer 2: Tenant Roles

These belong to a waste-management company tenant.

Roles:

```text
tenant_admin
tenant_manager
tenant_csr
tenant_dispatch
```

Scope:

```text
One platform_tenant row, such as KC Disposal or Mountain High Disposal
```

Stored in target table:

```text
user_tenant_roles
```

Interim storage:

```text
user_platform_roles
```

### Layer 3: HOA Roles

These belong to an HOA community.

Roles:

```text
hoa_manager
hoa_board
```

Scope:

```text
One or more HOA communities
```

Stored in existing table:

```text
user_hoa_memberships
```

### Layer 4: Resident Roles

Residents belong to verified HOA/address memberships.

Role:

```text
resident
```

Scope:

```text
Verified HOA/address membership
```

Stored across:

```text
user_hoa_memberships
user_address_memberships
residency_verifications
```

---

# 3. Recommended Role Migration Plan

## Add New Roles

Add:

```text
platform_owner
platform_admin
platform_support
platform_sales
tenant_admin
tenant_manager
```

Keep:

```text
tenant_csr
tenant_dispatch
hoa_manager
hoa_board
resident
```

Deprecate:

```text
sys_admin
mgmt
```

## Current-to-Target Mapping

| Current Role | Target Role | Scope | Action |
| --- | --- | --- | --- |
| `sys_admin` | `tenant_admin` | tenant | Add new role, migrate assignments, keep deprecated alias temporarily |
| `mgmt` | `tenant_manager` | tenant | Add new role, migrate assignments, keep deprecated alias temporarily |
| `csr` | `tenant_csr` | tenant | Rename for SaaS clarity |
| `dispatch` | `tenant_dispatch` | tenant | Rename for SaaS clarity |
| `hoa_manager` | `hoa_manager` | HOA | Keep |
| `hoa_board` | `hoa_board` | HOA | Keep |
| `resident` | `hoa_resident` | resident/address | Rename for SaaS clarity |
| none | `platform_owner` | global | Add |
| none | `platform_admin` | global | Add |
| none | `platform_support` | global | Add |
| none | `platform_sales` | global | Add |

## Migration Strategy

Do not remove `sys_admin` and `mgmt` immediately.

Recommended sequence:

1. Add target roles.
2. Add target permissions.
3. Copy `sys_admin` role assignments to `tenant_admin`.
4. Copy `mgmt` role assignments to `tenant_manager`.
5. Update UI labels to prefer target roles.
6. Update RLS helpers to recognize both old and new roles during transition.
7. Stop assigning deprecated roles in Admin UI.
8. Remove deprecated roles only after data and policies are stable.

---

# 4. Database Migration Plan

## Phase A: Add SaaS Role Concepts

Add roles:

```text
platform_owner
platform_admin
platform_support
platform_sales
tenant_admin
tenant_manager
```

Add permissions:

```text
tenants.read
tenants.manage
tenant.users.read
tenant.users.manage
tenant.analytics.read
tenant.settings.manage
platform.tenants.read
platform.tenants.manage
platform.users.read
platform.users.manage
platform.analytics.read
platform.support.read
platform.support.manage
platform.audit.read
platform.settings.manage
```

## Phase B: Add Global Platform Role Assignment Table

Add table:

```text
user_global_roles
```

Suggested columns:

```text
user_id uuid references profiles(id)
role_id bigint references roles(id)
created_at timestamptz
assigned_by uuid references profiles(id)
```

Purpose:

Only true SaaS operator roles should live here.

## Phase C: Rename Tenant Role Concept

Long-term target:

```text
user_platform_roles -> user_tenant_roles
```

Recommended approach:

- Do not rename immediately if it will destabilize the app.
- First create compatibility views/functions.
- Update application and RLS helpers to use tenant terminology.
- Rename once all code references are clean.

Interim compatibility option:

```text
create view user_tenant_roles as select * from user_platform_roles;
```

Or better long-term:

```text
create table user_tenant_roles (...)
copy data from user_platform_roles
replace references gradually
```

## Phase D: Tenant Ownership Audit

Tables already tenant-derived by `hoa_id`:

```text
hoa_addresses
user_hoa_memberships
user_address_memberships
residency_verifications
activation_codes
activation_code_events
announcements
documents
service_schedules
tickets
ticket_events
ticket_attachments
```

For performance, safety, and reporting, consider adding explicit `tenant_id` to high-volume operational tables:

```text
residency_verifications
activation_codes
announcements
documents
service_schedules
tickets
admin_audit_logs
admin_user_invites
```

If explicit `tenant_id` is added, enforce consistency with `hoa_id` through triggers or check functions.

## Phase E: Tenant Branding And Settings

Add future table:

```text
tenant_settings
```

Suggested fields:

```text
tenant_id
support_email
support_phone
logo_url
primary_color
secondary_color
portal_hostname
email_from_name
email_reply_to
status
created_at
updated_at
```

This enables each paying waste company to have its own branded portal.

---

# 5. RLS Migration Plan

## Current Problem

Current policies use:

```text
is_kcd_staff()
is_sys_admin()
has_platform_role()
```

These names do not fit SaaS.

## Target Helper Functions

Add new helper functions while keeping old functions temporarily.

Recommended helpers:

```text
global_role_codes()
tenant_role_codes(_tenant_id uuid)
hoa_role_codes(_hoa_id uuid)

has_global_role(_role text)
has_any_global_role(_roles text[])
has_tenant_role(_tenant_id uuid, _role text)
has_any_tenant_role(_tenant_id uuid, _roles text[])
has_hoa_role(_hoa_id uuid, _roles text[])

is_platform_owner()
is_platform_admin()
is_platform_support()
is_platform_sales()
is_platform_operator()

is_tenant_admin(_tenant_id uuid)
is_tenant_manager(_tenant_id uuid)
is_tenant_staff(_tenant_id uuid)
can_access_tenant(_tenant_id uuid)
can_manage_tenant(_tenant_id uuid)

hoa_tenant_id(_hoa_id uuid)
ticket_tenant_id(_ticket_id uuid)
can_read_ticket(_ticket_id uuid)
```

## Transitional Helpers

Keep existing functions but rewrite them as wrappers:

```text
is_sys_admin() -> has tenant_admin legacy/sys_admin role for current tenant, or platform operator if applicable
is_kcd_staff() -> deprecated wrapper, eventually removed
has_platform_role() -> deprecated wrapper around tenant roles during transition
```

## Policy Direction

Policies should not ask:

```text
is_kcd_staff()
```

They should ask:

```text
is_tenant_staff(record_tenant_id)
```

or:

```text
is_platform_operator()
```

Examples:

HOA select:

```text
user is platform operator
or user has tenant role for hoa_communities.tenant_id
or user has HOA role for hoa_communities.id
or user is resident in HOA
```

Ticket select:

```text
requester_user_id = auth.uid()
or user has HOA role for ticket.hoa_id
or user has tenant staff role for ticket tenant
or user is platform support/admin/owner
```

Tenant select:

```text
platform operator can see all tenants
tenant staff can see their own tenant
HOA users can see tenant only through their HOA context if needed
```

## Storage Policies

Current storage paths:

```text
hoa-documents/{hoa_id}/{document_id}/{filename}
ticket-attachments/{hoa_id}/{ticket_id}/{filename}
```

This can remain because `hoa_id` derives tenant.

Future option:

```text
hoa-documents/{tenant_id}/{hoa_id}/{document_id}/{filename}
ticket-attachments/{tenant_id}/{hoa_id}/{ticket_id}/{filename}
```

Recommended near-term:

Keep current paths, but update policies to use tenant-aware helpers through `hoa_id`.

Recommended long-term:

Add tenant ID to storage paths when introducing tenant-level backup/export, tenant deletion, or branded storage organization.

---

# 6. Admin Web App Navigation And RBAC Migration Plan

## Current Navigation Groups

Current app has platform-like admin navigation:

```text
Dashboard
HOA Management
Address Registry
Activation Codes
Resident Verification
Announcements
Documents
Service Schedules
Tickets
Users & Roles
Audit Logs
```

Current HOA-scoped navigation:

```text
HOA Dashboard
Residents
Documents
Announcements
Tickets
Service Schedules
```

## Target Navigation Groups

### Platform Operator Navigation

Visible to:

```text
platform_owner
platform_admin
platform_support
platform_sales
```

Navigation:

```text
Platform Dashboard
Tenants
Tenant Onboarding
Global Users
Support Console
Global Analytics
Audit Logs
Platform Settings
```

### Tenant Admin Navigation

Visible to:

```text
tenant_admin
tenant_manager
tenant_csr
tenant_dispatch
```

Navigation depends on permissions:

```text
Tenant Dashboard
HOA Management
Address Registry
Activation Codes
Resident Verification
Announcements
Documents
Service Schedules
Tickets
Users & Roles
Audit Logs
Analytics
Tenant Settings
```

### HOA Navigation

Visible to:

```text
hoa_manager
hoa_board
```

Navigation:

```text
HOA Dashboard
Residents
Announcements
Documents
Tickets
Service Schedules
```

### Resident Navigation

Future app/mobile navigation:

```text
Resident Dashboard
Announcements
Documents
Service Schedule
My Tickets
Profile
```

## RBAC Service Changes

Current service:

```text
platformRolesForUser()
hoaRolesForUser()
```

Target service:

```text
globalRolesForUser()
tenantRolesForUser()
hoaRolesForUser()
residentScopesForUser()
```

Current access object:

```text
AdminAccess.platformRoles
AdminAccess.hoaRoles
AdminAccess.permissions
```

Target access object:

```text
AdminAccess.globalRoles
AdminAccess.tenantRoles
AdminAccess.hoaRoles
AdminAccess.permissions
AdminAccess.tenantScopeIds
AdminAccess.hoaScopeIds
```

---

# 7. Tenant Onboarding Workflow

## Goal

A SaaS operator should be able to onboard a new waste-management company without writing SQL.

## Workflow

1. Platform owner/admin creates tenant.
2. System creates tenant settings and default branding.
3. Platform owner/admin invites first tenant admin.
4. Tenant admin accepts invite.
5. Tenant admin configures company profile.
6. Tenant admin creates/imports HOA communities.
7. Tenant admin imports HOA addresses.
8. Tenant admin invites tenant staff, CSR, dispatch, HOA managers, and HOA board members.
9. Tenant staff generates activation codes.
10. Residents register through address and activation-code verification.

## Required Admin UI

Add Platform Tenant Management:

```text
Tenant List
Tenant Detail
Create Tenant
Edit Tenant
Tenant Status
Tenant Branding
Tenant Admins
Tenant Users
Tenant Usage
Tenant Audit
```

## Required Edge Functions

Future functions:

```text
create-tenant
invite-tenant-admin
update-tenant-branding
provision-tenant-defaults
```

Existing function to update:

```text
invite-admin-user
```

Target behavior:

- platform operators can invite tenant admins
- tenant admins can invite tenant users within their tenant
- tenant admins cannot invite global platform users
- tenant users cannot assign roles outside their tenant
- HOA managers cannot invite tenant staff unless explicitly allowed

---

# 8. Risks And Sequencing

## Highest Risks

### Risk 1: Cross-Tenant Data Exposure

Mitigation:

- prioritize tenant-aware RLS helpers
- test every table with Tenant A and Tenant B users
- add RLS regression tests before onboarding paid tenants

### Risk 2: Role Naming Confusion

Mitigation:

- introduce target roles before removing old roles
- keep aliases temporarily
- update UI labels first
- migrate data carefully

### Risk 3: Breaking KC Disposal Admin Access

Mitigation:

- map current `sys_admin` to `tenant_admin`
- map current `mgmt` to `tenant_manager`
- keep old helpers operational during transition
- test KC Disposal users after each migration

### Risk 4: Edge Function Privilege Leakage

Mitigation:

- update Edge Functions to distinguish global vs tenant admins
- never expose service role key to Flutter
- audit every privileged Edge Function action

### Risk 5: Storage Policy Drift

Mitigation:

- keep path structure stable short-term
- update storage policies through tenant-aware helpers
- add storage RLS tests

---

# 9. Exact Implementation Phases

## Phase 0: Freeze Feature Work

Status: Immediate.

Rules:

- no new feature modules
- no mobile expansion
- no billing
- no commercial/roll-off work
- no resident portal expansion
- only SaaS foundation correction work

Deliverables:

- this ADR
- implementation checklist
- test plan

## Phase 1: Role Catalog Correction

Deliverables:

- add SaaS platform roles
- add tenant roles
- map legacy roles
- add missing permissions
- mark `sys_admin` and `mgmt` as deprecated in documentation
- keep current assignments working

Implementation notes:

- create new migration
- do not delete old roles yet
- update seed data idempotently

## Phase 2: Global Platform Role Layer

Deliverables:

- add `user_global_roles`
- add global role RLS helpers
- add global role Admin Web App service support
- add initial platform owner assignment path

Implementation notes:

- platform roles should not be stored in tenant role tables
- platform support access must be audit-visible

## Phase 3: Tenant Role Clarification

Deliverables:

- introduce tenant-role helpers
- update `is_kcd_staff()` usages to tenant-aware equivalents
- update Admin Web App RBAC naming from platform roles to tenant roles
- keep compatibility wrappers temporarily

Implementation notes:

- defer physical rename from `user_platform_roles` to `user_tenant_roles` until code references are clean

## Phase 4: Tenant-Aware RLS Hardening

Deliverables:

- update RLS helpers
- update table policies
- update storage policies
- add Tenant A vs Tenant B RLS tests
- verify KC Disposal still works

Minimum RLS test matrix:

```text
platform_owner can see all tenants
tenant_admin can see only own tenant
tenant_manager can see only own tenant
tenant_csr can see only own tenant support data
tenant_dispatch can see only own tenant dispatch data
hoa_manager can see only assigned HOA
hoa_board can see only assigned HOA
resident can see only own resident-scoped data
Tenant A cannot see Tenant B data
```

## Phase 5: Admin Web App SaaS Navigation

Deliverables:

- platform navigation group
- tenant navigation group
- HOA navigation group
- role-aware dashboard routing
- tenant context display
- tenant switcher for platform roles

Implementation notes:

- `/admin` should route based on highest role scope
- platform users should land on Platform Dashboard
- tenant users should land on Tenant Dashboard
- HOA users should land on HOA Dashboard

## Phase 6: Tenant Management UI

Deliverables:

- Tenant List
- Tenant Detail
- Create Tenant
- Edit Tenant
- Tenant Status
- Tenant Branding
- Tenant Admin Assignment
- Tenant Usage Summary

Implementation notes:

- this is the next major feature after RBAC/RLS correction
- use real Supabase queries
- do not require SQL for onboarding

## Phase 7: Tenant Invite And Provisioning Edge Functions

Deliverables:

- update `invite-admin-user` for global vs tenant authorization
- add tenant admin invite support
- add tenant provisioning defaults
- add invite audit logging by tenant

Implementation notes:

- platform admins can invite tenant admins
- tenant admins can invite tenant staff and HOA users in their tenant
- tenant admins cannot grant platform roles

## Phase 8: Tenant Branding And Domain Support

Deliverables:

- tenant logo
- tenant colors
- tenant support email and phone
- tenant email template data
- tenant hostname/subdomain strategy

Implementation notes:

- start with tenant branding in app state
- later add custom domains or subdomains

---

# 10. Immediate Next Prompt

This prompt is retained for historical context. Before using it, apply ADR 0002 and adjust naming, signup, roles, and billing limits to the customer portal model.

Recommended historical implementation prompt:

```text
Implement Phase 1 of the SaaS Foundation Correction Plan.

Scope:
- Add SaaS platform roles
- Add tenant roles
- Keep legacy sys_admin and mgmt working
- Add required permissions
- Create idempotent migration
- Do not update RLS policies yet
- Do not update Admin Web App yet
- Return modified files only
```

After Phase 1 passes, proceed to Phase 2.

---

# 11. Final Recommendation

Do not onboard the six interested companies until at least these are complete:

1. Role catalog correction
2. Global platform role layer
3. Tenant-aware RLS helpers
4. Tenant isolation RLS tests
5. Tenant management UI foundation

The current product is strong enough to evolve. The correction is mainly about making the authorization and tenant model match the business before revenue customers depend on it.

---

# 12. Subscription Billing, Add-Ons, And Tenant Communications

## Why This Belongs In The Foundation

The HOA Portal is expected to be sold as a subscription product to multiple waste-management companies. Subscription payments, add-on features, and tenant-owned communication settings must be included in the SaaS foundation so they are not bolted on later in a risky way.

This does not mean billing must be implemented before tenant isolation. It means the architecture must reserve the correct concepts now.

The platform needs to support:

- recurring tenant subscriptions
- tenant-specific pricing
- platform-defined rates
- tenant add-ons
- Twilio texting add-ons
- tenant email sender configuration
- paid email delivery providers
- invoices and payment status
- subscription enforcement
- feature access based on plan/add-ons

## Commercial Role Ownership

Platform roles must control pricing and commercial settings.

Recommended permissions:

```text
billing.read
billing.manage
plans.read
plans.manage
subscriptions.read
subscriptions.manage
addons.read
addons.manage
rates.read
rates.manage
communications.read
communications.manage
```

Recommended role access:

| Role | Billing Access | Rate Setting | Add-On Management | Tenant Payment Visibility |
| --- | --- | --- | --- | --- |
| `platform_owner` | Full | Full | Full | Full |
| `platform_admin` | Full | Full or limited by policy | Full | Full |
| `platform_sales` | Read/write subscriptions and quotes | Limited | Can propose/add add-ons | Tenant commercial view |
| `platform_support` | Read-only | None | Read-only | Limited |
| `tenant_admin` | Own tenant only | None | Can request/enable allowed add-ons | Own tenant invoices/subscription |
| `tenant_manager` | Own tenant read-only | None | Request only, optional | Own tenant read-only |

## Recommended Billing Model

The SaaS platform should eventually support subscription plans plus add-ons.

Example plan structure:

```text
Base HOA Portal Subscription
  includes:
    HOA management
    resident verification
    documents
    announcements
    schedules
    tickets
    admin users up to plan limit
    HOA communities up to plan limit

Add-ons:
  SMS notifications
  advanced email sending
  branded portal/domain
  extra HOA communities
  extra admin seats
  analytics package
  priority support
```

## Recommended E-Commerce Provider

Use a dedicated payment provider instead of building payment processing directly.

Recommended provider:

```text
Stripe Billing
```

Reasons:

- recurring subscriptions
- invoices
- payment methods
- coupons/discounts
- customer portal
- metered billing
- tax support
- webhooks
- strong SaaS ecosystem

Supabase should store billing state, but Stripe should be the system of record for payment collection.

## Recommended Billing Tables

Future tables:

```text
subscription_plans
subscription_plan_prices
tenant_subscriptions
tenant_subscription_items
tenant_addons
tenant_invoices
tenant_payment_events
tenant_billing_contacts
```

Suggested responsibilities:

### `subscription_plans`

Stores platform-defined plans.

Example fields:

```text
id
code
name
description
status
created_at
updated_at
```

### `subscription_plan_prices`

Stores rates controlled by platform roles.

Example fields:

```text
id
plan_id
billing_interval
currency
unit_amount_cents
stripe_price_id
status
effective_at
created_at
updated_at
```

### `tenant_subscriptions`

Stores a tenant's active subscription state.

Example fields:

```text
id
tenant_id
plan_id
stripe_customer_id
stripe_subscription_id
status
current_period_start
current_period_end
trial_end
cancel_at
created_at
updated_at
```

### `tenant_addons`

Stores enabled tenant add-ons.

Example fields:

```text
id
tenant_id
addon_code
status
stripe_subscription_item_id
configuration_json
enabled_at
disabled_at
created_at
updated_at
```

### `tenant_billing_contacts`

Stores billing contacts for tenant subscribers.

Example fields:

```text
id
tenant_id
name
email
phone
is_primary
created_at
updated_at
```

## Tenant Add-On Model

Add-ons should control feature availability.

Recommended add-on codes:

```text
sms_notifications
custom_email_provider
custom_branding
custom_domain
advanced_analytics
priority_support
extra_admin_seats
extra_hoa_communities
```

The app should not simply check whether a UI button exists. It should check tenant entitlement.

Recommended helper concept:

```text
tenant_has_addon(tenant_id, addon_code)
tenant_has_feature(tenant_id, feature_code)
```

## Twilio SMS Add-On

If a tenant wants texting features, SMS should be an add-on.

Recommended approach:

- platform owns the Twilio integration by default
- tenant enables SMS add-on
- tenant may optionally provide its own approved sending number later
- all SMS sends are logged
- SMS usage can be billed monthly

Future tables:

```text
tenant_sms_settings
sms_messages
sms_usage_events
```

Suggested `tenant_sms_settings` fields:

```text
tenant_id
is_enabled
twilio_subaccount_sid
twilio_messaging_service_sid
from_phone_number
monthly_message_limit
status
created_at
updated_at
```

Suggested `sms_messages` fields:

```text
id
tenant_id
recipient_user_id
recipient_phone
template_code
body
status
provider_message_id
error_message
sent_at
created_at
```

Security requirements:

- tenants must only send SMS to their own residents/users
- opt-out handling must be supported
- message history must be tenant-scoped
- platform support must have audited access
- SMS credentials must never be exposed to Flutter

Recommended Edge Functions:

```text
send-tenant-sms
sync-twilio-message-status
```

## Tenant Email Configuration

The platform should not rely on free/default email plans for production tenant notifications.

Supabase Auth email is useful, but production tenant email needs deliberate configuration.

Recommended options:

1. Platform-managed email provider
2. Tenant-branded sending identities
3. Tenant-owned email provider configuration, optional later

Recommended provider options:

```text
Resend
SendGrid
Postmark
Amazon SES
```

For this product, a practical starting point is:

```text
Platform-managed Resend/Postmark with tenant-specific sender identities
```

Future tables:

```text
tenant_email_settings
email_templates
email_messages
email_events
```

Suggested `tenant_email_settings` fields:

```text
tenant_id
from_name
from_email
reply_to_email
provider
provider_domain_status
provider_sender_status
is_enabled
created_at
updated_at
```

Suggested `email_templates` fields:

```text
id
tenant_id
template_code
subject
body_html
body_text
status
created_at
updated_at
```

Suggested `email_messages` fields:

```text
id
tenant_id
recipient_user_id
recipient_email
template_code
subject
status
provider_message_id
error_message
sent_at
created_at
```

Recommended Edge Functions:

```text
send-tenant-email
sync-email-provider-events
```

Tenant email requirements:

- each tenant should provide billing email
- each tenant should provide support email
- each tenant should provide default notification sender name
- platform should validate sender/domain setup before enabling branded email
- failed email sends should be logged
- provider webhooks should update delivery status

## Supabase Auth Email Consideration

Supabase Auth can send authentication emails, but for production SaaS the platform should not rely on free/default email delivery.

Recommended path:

- keep Supabase Auth for authentication flows
- configure custom SMTP or provider-backed auth email before production onboarding
- use tenant email settings for non-auth notifications
- use branded email templates for invites where possible

Important distinction:

```text
Auth emails = account login, password reset, invite confirmation
Application emails = tickets, announcements, document notifications, reminders
```

Auth emails may still be sent through Supabase Auth, but production should use paid SMTP/provider settings.

## Billing And Feature Enforcement

Subscription status should eventually control tenant access.

Example statuses:

```text
trialing
active
past_due
paused
cancelled
expired
```

Recommended enforcement:

- `trialing` tenants get plan features
- `active` tenants get plan features
- `past_due` tenants get grace-period access
- `paused` tenants lose resident-facing sends and new activation codes
- `cancelled` tenants become read-only after grace period
- platform owners/admins can override access

Feature checks should happen in:

- Admin Web App navigation
- Edge Functions
- RLS helper functions where relevant
- backend notification functions

## Tenant Management UI Additions

Platform Tenant Management should include commercial sections.

Recommended pages/sections:

```text
Tenant Detail
  Overview
  Subscription
  Plan & Rates
  Add-Ons
  Billing Contacts
  Payment Status
  Email Settings
  SMS Settings
  Branding
  Usage
  Audit Log
```

Platform roles should be able to:

- set tenant plan
- set subscription rate
- apply discounts
- enable/disable add-ons
- configure billing contacts
- view payment status
- configure email sender information
- enable SMS add-on
- view communication usage

Tenant admins should be able to:

- view current plan
- view invoices/payment status
- request add-ons
- configure support email
- configure notification preferences
- view SMS/email usage if enabled

## Updated Roadmap Impact

Billing and communications should be added to the roadmap after tenant isolation but before broad paid onboarding.

Updated implementation order:

1. Role catalog correction
2. Global platform role layer
3. Tenant-aware RLS helpers
4. Tenant isolation tests
5. Tenant Management UI foundation
6. Subscription/billing data model
7. Stripe Billing integration
8. Tenant email settings
9. Paid SMTP/provider configuration
10. SMS add-on data model
11. Twilio integration
12. Branding/domain support

## Commercial Readiness Gate

Before onboarding paying tenants beyond the first pilot customers, the platform should have:

- tenant isolation tested
- tenant admin onboarding
- platform role controls
- subscription status tracking
- billing contact records
- tenant support email settings
- production email provider plan
- audit logging for billing and communications changes

Stripe and Twilio do not have to be fully automated on day one, but the data model should be ready so manual subscription setup does not become technical debt.
