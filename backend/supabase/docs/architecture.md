# Supabase Architecture

Supabase provides the local and hosted backend for the Waste Hauler Customer Portal SaaS.

## Core Services

- Auth: shared identity for platform staff, tenant staff, community contacts, and customers.
- Postgres: tenant data, roles, customer accounts, service locations, tickets, documents, schedules, and announcements.
- RLS: tenant, role, customer, city/community, and service-location isolation.
- Storage: customer-visible documents and ticket attachments.
- Edge Functions: service-role workflows such as invites, customer verification, ticket detail, ticket updates, and signed document/attachment access.
- Mailpit locally: captures Supabase Auth and invite emails during development.

## Current Schema Shape

The product direction is customer-portal SaaS, but some schema and bucket names still include `hoa` from the first implementation slice.

Treat these as compatibility details:

- `hoa_communities`
- `hoa_addresses`
- `user_hoa_memberships`
- `hoa-documents`

New UI and product language should use:

- Tenant
- Customer
- City
- Community
- Service location
- Customer membership

## Local URLs

- App: `http://127.0.0.1:8080`
- Supabase API: `http://127.0.0.1:54321`
- Supabase Studio: `http://127.0.0.1:54323`
- Mailpit: `http://127.0.0.1:54324`
