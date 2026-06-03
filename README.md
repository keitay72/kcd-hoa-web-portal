# KC Disposal Phase 1

Monorepo skeleton for Phase 1 platform delivery.

## Stack

- Flutter (mobile + admin web)
- Supabase (Auth, PostgreSQL, RLS, Storage, Realtime, Edge Functions)

## Repo layout

- `apps/mobile_app`: Resident mobile app
- `apps/admin_web_app`: Admin web app
- `backend/supabase`: DB migrations, policies, functions, tests
- `packages`: Shared Dart packages
- `infra`: CI/CD and environment config
- `docs`: Product and engineering docs

## Quick start

1. Install Flutter and Dart.
2. Install Melos: `dart pub global activate melos`
3. Bootstrap workspace: `melos bootstrap`
4. Copy env template: `cp .env.example .env`

## Notes

- This skeleton intentionally excludes feature implementation code.
