# Database Setup

This project uses Supabase migrations under:

```text
backend/supabase/migrations
```

## Required Local Tools

- Supabase CLI
- Docker Desktop or another Docker-compatible runtime
- Flutter SDK for app-side checks

The Supabase CLI can apply and reset the local database, but the local Supabase
stack still needs Docker.

## Local Migration Flow

From the repository root:

```sh
supabase start
supabase db reset
```

After `supabase db reset`, verify the new customer portal tables exist:

```sh
supabase db diff --local
```

The expected customer portal migrations are:

- `0035_customer_portal_foundation.sql`
- `0036_backfill_customer_portal_from_hoa.sql`
- `0037_customer_portal_subscription_catalog.sql`

## Current Machine Notes

On this development machine, `psql` is available, but `supabase` and `docker`
were not installed when the customer portal migration work started.

Homebrew was available, but installing the Supabase CLI through the
`supabase/tap` tap required persistent tap trust. That step should be approved
explicitly before running:

```sh
brew trust supabase/tap
brew install supabase/tap/supabase
```

An `npx supabase --version` attempt also stalled while resolving the package, so
the local database migrations have not yet been executed on this machine.

## Remote Project Flow

For a linked remote project:

```sh
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase db push
```

Only run `supabase db push` against a disposable development project until the
customer portal migrations have been tested with representative HOA data.
