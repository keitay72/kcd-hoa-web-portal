# Bootstrap Notes

This machine was freshly set up for the project, so local development requires a
small toolchain bootstrap before database-backed work can be verified end to end.

## App Dependencies

From the admin Flutter app:

```sh
cd apps/admin_web_app
flutter pub get
flutter test
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

The admin app is served locally at:

```text
http://127.0.0.1:8080
```

## Database Dependencies

The customer portal migrations require Supabase CLI plus Docker.

Check current availability:

```sh
which supabase
which docker
psql --version
```

If Supabase CLI and Docker are missing, install them before trying to run
`supabase start` or `supabase db reset`.

## Verification Targets

After bootstrap, the minimum checks for the customer portal pivot are:

```sh
cd apps/admin_web_app
flutter test test/customer_account_models_test.dart test/tenant_entitlements_test.dart
dart analyze lib/features/customer_accounts test/customer_account_models_test.dart
flutter build web --debug
```

Then run the Supabase migration reset from the repository root:

```sh
supabase db reset
```
