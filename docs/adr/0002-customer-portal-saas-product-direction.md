# ADR 0002: Customer Portal SaaS Product Direction

Date: 2026-06-21
Status: Proposed
Owner: Waste Hauler Customer Portal SaaS Project

## Decision

Reposition the product from an HOA portal SaaS into a white-label customer portal SaaS for waste haulers.

The platform will be sold to trash companies around the country. Each subscribed trash company will use the SaaS to provide a branded customer portal to its own customers.

The target model is:

```text
Customer Portal SaaS Platform
  SaaS operator
    Platform marketing site and platform administration
  Waste-hauler tenants
    KC Disposal
    Mountain High Disposal
    Olathe Disposal
    Future subscribed companies
  Tenant-branded portals
    portal.kcdisposal.com
    portal.mountainhighdisposal.com
    portal.olathewasteinc.com
  Customer accounts and service locations
    Residential
    HOA/community
    Commercial
    Roll-off
  Customer users
```

ADR 0001 remains useful for tenant isolation, RBAC, billing, and SaaS foundation work. This ADR supersedes ADR 0001 where ADR 0001 describes the product as an HOA-centered portal.

## Product Surfaces

The product has two primary web surfaces.

1. Platform marketing site

   Example: `portal.com`

   This is the public-facing sales website for the SaaS product. It is aimed at waste-hauler buyers and should explain the product, pricing, onboarding, and subscription value.

2. Tenant customer portal

   Example: `portal.olathewasteinc.com`

   This is the branded portal used by a tenant's customers and staff. It should feel like it belongs to the trash company, using tenant branding, support contacts, documents, schedules, service request types, and portal configuration.

For the first version, each tenant should have one configured portal hostname. Avoid designing for multiple custom domains per tenant until there is a clear need.

## Identity And Login

The platform should have one login experience for every user.

Authentication answers:

```text
Who is this person?
```

Authorization answers:

```text
Which tenant, customer account, service location, role, and workspace can this person access?
```

Do not create separate login pages for platform admins, tenant staff, HOA users, residential customers, commercial customers, or roll-off customers. The same login should route users based on their roles and memberships.

After login:

- Platform users land in platform administration.
- Tenant admins land in tenant administration.
- CSR and dispatch users land in operational queues.
- Community admins land in their community workspace.
- Customer users land in their customer portal.
- Users with multiple contexts should see a context switcher or deterministic default context.

## Customer Signup

The preferred signup flow should not require mailed activation codes.

Target flow:

1. Customer visits the tenant-branded portal.
2. Customer enters service address and email.
3. The system checks whether the address exists for that tenant.
4. If eligible, the system creates a pending registration tied to the service location.
5. The system sends a verification email.
6. Customer clicks the email link.
7. Customer sets up password, name, phone, and profile details.
8. Customer account becomes active and linked to the service location.

Activation codes should become optional compatibility or strict-mode verification. They should not be the default onboarding method.

Security posture:

- Email verification proves email ownership.
- Address matching proves the service location exists in the tenant's registry.
- This is sufficient for low-risk portal features such as documents, schedules, announcements, and service requests.
- Future sensitive features, such as billing history or payments, may require stronger verification such as account number, invoice token, staff approval, or direct system integration.
- Multiple users may be associated with the same service location.

## Domain Model Direction

The current implementation uses HOA-centered tables such as:

- `hoa_communities`
- `hoa_addresses`
- `user_hoa_memberships`
- `user_address_memberships`
- `residency_verifications`

These tables remain valid current implementation details, but new design work should move toward broader concepts:

- `platform_tenants`: waste-hauler subscribers.
- Customer account: a tenant-owned customer relationship or billing/service account.
- Service context: a tenant-owned grouping such as city, HOA/community, route, commercial account, or roll-off account.
- Service location: a physical address or serviced location.
- Customer user: a profile that can access one or more customer accounts, service contexts, or service locations.

Possible future hierarchy:

```text
platform_tenants
  customer_accounts
    service_locations
      customer_memberships
```

HOA/community should be one supported customer account or service context type, not the top-level product model.

Documents, announcements, schedules, and tickets should eventually attach to tenant, customer account, service context, or service location scopes instead of requiring `hoa_id`.

## Roles

Roles should exist only when they create meaningfully different permissions or workspaces.

Target role groups:

- Platform roles: `platform_owner`, `platform_admin`, `platform_support`, `platform_sales`.
- Tenant roles: `tenant_admin`, `tenant_manager`, `tenant_csr`, `tenant_dispatch`.
- Community role: `community_admin`.
- Customer role: `customer_user`.

Existing HOA roles should be treated as compatibility roles:

- `hoa_manager`
- `hoa_board`
- `hoa_resident`

The product should avoid keeping both HOA Manager and HOA Board Member unless they truly have distinct permissions. The target customer-portal model should use one community-level admin role for HOA board members, property managers, or similar community contacts.

## Pricing And Tiers

Subscription tiers should control capacity, not core functionality.

All paid tiers should include the complete core customer portal feature set:

- Tenant-branded portal.
- Customer signup.
- Customer profiles.
- Customer accounts and service locations.
- Documents.
- Announcements.
- Service schedules.
- Service requests/tickets.
- Staff/admin access.
- Role-based dashboards.
- Email notifications.
- Standard support.

Target public plan bands:

```text
Local
  up to 10,000 active customers/service locations

Regional
  up to 30,000 active customers/service locations

Metro
  up to 75,000 active customers/service locations

Enterprise
  75,000+ active customers/service locations
```

KC Disposal and Mountain High Disposal each have roughly 58,000 to 60,000 residential customers, so they fit the Metro band under this model.

Recommended overage policy:

- Include a small grace buffer.
- Bill modest overages above the buffer.
- Require upgrade when usage remains materially above plan capacity for multiple billing cycles.

Suggested public pricing direction:

```text
Local:      up to 10,000 customers/service locations
Regional:  up to 30,000 customers/service locations
Metro:     up to 75,000 customers/service locations
Enterprise: custom
```

Exact prices can be adjusted before launch, but feature access should not be split across tiers.

Valid add-ons should map to real external cost or heavier operational load:

- SMS messaging.
- Custom email sending domain.
- Advanced integrations/API access.
- White-glove data import/onboarding.
- Premium support/SLA.

Avoid core-feature add-ons such as documents, schedules, tickets, branding, or basic customer registration.

## Near-Term Implementation Direction

Do not continue expanding the product as if HOA is the central model.

Recommended next implementation sequence:

1. Update product language from HOA Portal to Customer Portal where it affects future-facing docs, navigation, onboarding, and marketing.
2. Add or formalize tenant portal hostname resolution using `tenant_settings.portal_hostname`.
3. Consolidate toward one login flow for all user types.
4. Replace activation-code-first registration with address match plus email verification.
5. Design customer account/service location schema before expanding commercial or roll-off workflows.
6. Simplify community-level roles and avoid creating new workflows that depend on separate HOA Manager and HOA Board Member roles.
7. Update subscription plan data to use customer/service-location limits instead of HOA/resident limits.
8. Add overage tracking based on active customers/service locations.

## Non-Goals For The Next Pass

- Do not build separate login pages for each user type.
- Do not make feature-gated subscription tiers for core portal functionality.
- Do not add new activation-code requirements unless a tenant explicitly chooses strict verification.
- Do not expand the deferred mobile app before the web portal model is stable.
- Do not treat roll-off and commercial as separate products. They are future account/context types inside the same portal platform.

## Rationale

The HOA portal was a useful first slice, but the commercial product is broader: waste haulers need a customer portal for all customer types. Repositioning now prevents the schema, routes, roles, pricing, and sales message from becoming too HOA-specific.

This direction preserves the existing SaaS foundation while shifting the customer layer from HOA/resident concepts toward customer accounts, service locations, and role-based workspaces.
