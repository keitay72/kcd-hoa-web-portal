# UI/UX Redesign Plan

Status: Draft
Last updated: 2026-06-21

## Purpose

Define the visual and experience direction for the customer portal SaaS so the product does not feel like a generic Flutter starter app.

This plan should guide future UI work after the customer portal model, routing, and signup foundations are stable enough to support real screens.

## Decision

The app should become a polished, professional waste-hauler SaaS product with tenant-branded customer portal experiences.

The product should feel:

- Operationally trustworthy.
- Fast to scan.
- Purpose-built for trash companies and their customers.
- Clean and modern without feeling like a marketing template.
- Mobile-first for customer workflows.
- Dense and efficient for admin/operations workflows.

## Product Surfaces

The UI needs distinct but related experiences:

1. Platform admin
   - Used by the SaaS operator.
   - Manages tenants, billing, onboarding, roles, and platform support.

2. Tenant admin/operations
   - Used by trash company staff.
   - Manages customer accounts, service locations, tickets, schedules, documents, and customer support.

3. Community/customer admin
   - Used by HOA board members or community managers.
   - Manages community-level content and views service-related information.

4. Customer portal
   - Used by residential, HOA/community, commercial, and future roll-off customers.
   - Shows service information, documents, schedules, requests, and profile/account context.

5. Marketing site
   - Used to sell the SaaS to waste haulers.
   - May be separate from the Flutter portal app.

## Visual Direction

The interface should avoid the default Flutter starter-app feel.

Avoid:

- Generic Material starter colors.
- Oversized default app bars.
- Sparse demo-like screens.
- Card-heavy pages where every section floats.
- Feature-lock messaging across core portal features.
- Placeholder-ish copy like "Phase 1" or "Coming soon" in user-facing screens.

Prefer:

- A restrained, work-focused SaaS interface for admin screens.
- Clear navigation and strong information hierarchy.
- Tenant-branded but still consistent customer portal screens.
- Compact tables, filters, status chips, and action menus for operational workflows.
- Mobile-first forms and customer tasks.
- Consistent typography scale and spacing.
- Real empty states that tell staff/customers what to do next.

## Tenant Branding

Tenant portal screens should use tenant settings:

- `tenant_settings.logo_url`
- `tenant_settings.primary_color`
- `tenant_settings.secondary_color`
- `tenant_settings.support_email`
- `tenant_settings.support_phone`
- `tenant_settings.portal_hostname`

Branding rules:

- Tenant branding should be visible on login, signup, and customer portal screens.
- Tenant branding should not make the UI unreadable or inconsistent.
- Use tenant colors as accents, not full-page paint, unless a tenant-specific theme is deliberately designed.
- Keep operational admin views consistent enough that support/training remains manageable.

## Navigation Direction

### Platform Admin Navigation

Target sections:

- Dashboard
- Tenants
- Billing
- Onboarding
- Support
- Users & Roles
- Audit Logs
- Settings

### Tenant Admin Navigation

Target sections:

- Dashboard
- Customers
- Service Locations
- Requests
- Schedules
- Documents
- Announcements
- Staff
- Settings

### Customer Portal Navigation

Target sections:

- Home
- Schedule
- Requests
- Documents
- Profile

For customers, navigation should be simpler than the admin app. Avoid exposing operational concepts like tenant, role, or service context unless the customer needs to switch between accounts/locations.

## Key Screen Concepts

### Customer Home

Should answer immediately:

- What address/account am I viewing?
- What is my next pickup/service day?
- Are there any alerts or announcements?
- How do I report an issue?

Primary actions:

- Report service issue.
- View schedule.
- View documents.
- Manage profile.

### Service Request Flow

Mobile-first.

Expected fields:

- Service location.
- Request type.
- Description.
- Optional photo/file attachment.
- Contact preference.

UX requirements:

- Keep the form short.
- Use clear request type labels.
- Support photo upload from mobile.
- Show confirmation and next steps.

### Tenant Operations Dashboard

Should focus on active work:

- New/untriaged requests.
- Urgent/aging requests.
- Dispatch queue.
- Recently updated tickets.
- Signup/verification issues.
- Data import/onboarding blockers.

### Customer Account Detail

Should show:

- Account type.
- Service locations.
- Associated users.
- Open requests.
- Documents/schedules scoped to the account.
- Imported external references.

### Service Location Detail

Should show:

- Address.
- Status.
- Service schedule.
- Assigned customer users.
- Open/history requests.
- Related documents/announcements.

## PWA/Mobile Requirements

Customer-facing screens should be designed for mobile first.

Requirements:

- Works well at phone widths.
- Touch targets are comfortable.
- Forms avoid unnecessary typing.
- File/photo uploads work from mobile.
- Installed PWA display feels app-like.
- Deep links land in the expected place after login.

See:

- `docs/srs/pwa-mobile-strategy.md`
- `docs/srs/routing-auth-clean-url-plan.md`

## Component Direction

Build or standardize reusable components for:

- Tenant-aware app shell.
- Context/account switcher.
- Status chips.
- Service-location selector.
- Customer/account summary header.
- Request/ticket cards.
- Data tables with filters.
- Empty states.
- Confirmation and destructive-action dialogs.
- Mobile-first form sections.

Avoid creating new one-off UI patterns in every feature folder.

## Design System Direction

Future design system decisions should define:

- Color tokens.
- Tenant accent color usage.
- Typography scale.
- Spacing scale.
- Button styles.
- Form styles.
- Table/list density.
- Navigation patterns.
- Empty/loading/error states.
- Icons.

The initial goal is consistency and polish, not heavy custom theming.

## Phased Redesign Plan

### Phase 1: Design Direction And Shell

- Define app shell layout for admin and customer portal.
- Define navigation groups.
- Define typography/spacing/color tokens.
- Remove obvious starter-app visual defaults.

### Phase 2: Customer Portal Makeover

- Login/signup.
- Customer home.
- Schedule.
- Requests.
- Documents.
- Profile.

### Phase 3: Tenant Operations Makeover

- Tenant dashboard.
- Customers.
- Service locations.
- Tickets/requests.
- Schedules.
- Documents.

### Phase 4: Platform Admin Polish

- Tenant management.
- Billing/subscription views.
- Onboarding checklist.
- Audit/support tooling.

### Phase 5: PWA Polish

- Install experience.
- Mobile deep links.
- Offline fallback.
- Tenant icon/manifest strategy.

## Non-Goals

- Do not redesign every existing screen before the customer data model is stable.
- Do not build a marketing landing page inside the portal app unless that becomes the chosen deployment strategy.
- Do not overfit visual design to KC Disposal only.
- Do not create separate UI systems for every tenant.
- Do not let tenant colors break contrast, readability, or supportability.

## Open Questions

- Should the platform admin and tenant admin share one shell or use visually distinct shells?
- Should the customer portal have a separate lightweight shell from admin?
- What should the default SaaS brand be called publicly?
- Should tenant branding apply to tenant staff admin screens or only customer-facing portal screens?
- Should tenant-uploaded logos/icons be required during onboarding?
- Should the first redesign use Material 3 theming or a more custom component layer?
