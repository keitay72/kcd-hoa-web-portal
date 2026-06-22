# PWA And Mobile Strategy

Status: Draft
Last updated: 2026-06-21

## Purpose

Define the mobile strategy for the customer portal SaaS.

The product should prioritize a responsive web portal and Progressive Web App before any native mobile app buildout.

## Decision

The customer portal should be mobile-first responsive web and PWA-capable.

Do not build a native mobile app as the first mobile experience.

Reason:

- Each tenant wants the portal to feel like their trash company's portal.
- Some tenants, such as KC Disposal, may already have a mobile app.
- A native white-label app creates app store, branding, release, and support complexity.
- A PWA gives every tenant mobile access through the same tenant-branded portal hostname.

## Target User Experience

Desktop:

```text
https://portal.kcdisposal.com
```

Mobile browser:

```text
https://portal.kcdisposal.com
```

Installed PWA:

```text
KC Disposal Portal app icon
opens portal.kcdisposal.com
uses KC Disposal branding
```

Existing tenant mobile app:

```text
KC Disposal app -> Customer Portal button -> portal.kcdisposal.com
```

Customer-facing mobile UI should follow `docs/srs/ui-ux-redesign-plan.md`.

## Mobile Phases

### Phase 1: Responsive Web Portal

Make the web portal work well on phones:

- Customer signup.
- Login.
- Documents.
- Service schedules.
- Service requests.
- Account/service-location selection.
- Profile setup.

Design requirements:

- Mobile-first layouts.
- Large touch targets.
- Fast forms.
- Clear error states.
- Minimal typing where possible.
- File/photo attachments from mobile.

### Phase 2: PWA Foundation

Make the tenant portal installable where browser support allows it.

Requirements:

- Web app manifest.
- Tenant-aware app name and short name strategy.
- Tenant-aware icons or a safe default icon strategy.
- Theme color support.
- HTTPS.
- Service worker.
- Offline/fallback shell.
- Installability checks.

Important constraint:

Flutter Web currently ships a single static `manifest.json` by default. Tenant-specific PWA branding may require dynamic manifest handling or a platform-level manifest that uses neutral branding until tenant-specific manifest support is designed.

### Phase 3: Tenant App Link-In

Support existing tenant mobile apps by letting them link to the tenant portal.

Examples:

- Customer Portal
- Report Service Issue
- View Schedule
- Documents

Link style:

```text
https://portal.kcdisposal.com
https://portal.kcdisposal.com/requests/new
https://portal.kcdisposal.com/schedules
```

First version:

- Open portal in browser or in-app browser.
- User logs in through the same portal auth flow.

Future version:

- Secure SSO/deep-link handoff from tenant app if the tenant app already authenticates users.

### Phase 4: Optional Native Shell

Only consider a native app later if tenants demand it and the web/PWA portal is proven.

Possible options:

- One generic SaaS app with tenant lookup.
- White-label native app per tenant.
- Thin native wrapper around the portal.

Risks:

- App store release management.
- Tenant-specific branding and listings.
- Push notification setup per tenant.
- Support load.
- Duplicate native/web QA.

## PWA Capabilities

Initial PWA capabilities:

- Installable app icon.
- Full-screen or standalone display mode.
- Tenant-branded login and portal pages.
- Mobile-friendly service request forms.
- Attach photos/files to requests.
- Basic offline fallback page.

Later PWA capabilities:

- Push notifications for ticket updates or service alerts.
- Cached documents or schedules.
- Background sync for draft service requests.

Do not depend on later PWA capabilities for the first customer portal launch.

## Tenant Branding Considerations

Tenant branding comes from tenant settings:

- `tenant_settings.portal_hostname`
- `tenant_settings.logo_url`
- `tenant_settings.primary_color`
- `tenant_settings.secondary_color`
- `tenant_settings.support_email`
- `tenant_settings.support_phone`

PWA branding decisions still needed:

- Should each tenant get tenant-specific manifest values?
- Should tenant icons be generated/uploaded during onboarding?
- Should the first PWA use neutral SaaS icons while pages themselves are tenant-branded?
- How should browser caching behave when manifest content changes by hostname?

## Auth And Routing Requirements

PWA must follow the same routing and auth model defined in:

- `docs/srs/routing-auth-clean-url-plan.md`

Important requirements:

- No `#` URLs in final PWA routes.
- One login page.
- Tenant hostname resolution before signup/login display.
- Auth callbacks must work in mobile browsers and installed PWA context.
- Deep links should open the intended route after login when possible.

## Existing Mobile App Directory

The current `apps/mobile_app` directory should remain deferred.

Near-term rule:

- Do not expand `apps/mobile_app` until the responsive web/PWA portal is stable.

Possible future use:

- White-label native shell.
- Tenant app wrapper.
- Shared mobile experiments.

But it is not required for the SaaS launch.

## Tenant-Owned Mobile App Integration

For tenants with existing apps, such as KC Disposal:

- Add a button or menu item in the tenant's existing app.
- Link to the tenant portal hostname.
- Let the portal handle login, customer context, and authorization.

Future SSO option:

- Tenant app requests a signed handoff token.
- Portal validates token.
- Portal creates or resumes session.
- User lands in the intended route.

Do not build SSO handoff until a tenant app integration requires it.

## Testing Checklist

Test on:

- iPhone Safari.
- iPhone installed PWA.
- Android Chrome.
- Android installed PWA.
- Desktop Chrome.
- Desktop Safari.

Test flows:

- Load tenant portal.
- Install PWA.
- Open installed PWA.
- Sign up.
- Verify email.
- Log in.
- Submit service request with photo.
- View schedule.
- View document.
- Sign out.
- Open a deep link while signed out.
- Open a deep link while signed in.

## Non-Goals

- Do not build native iOS/Android apps for the first launch.
- Do not require tenants to replace existing mobile apps.
- Do not require app store distribution for tenant customer access.
- Do not build push notifications before the core portal is stable.
- Do not build tenant-app SSO until a tenant integration requires it.
