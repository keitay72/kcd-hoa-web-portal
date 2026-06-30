# Admin Web App

Flutter Web app for the Waste Hauler Customer Portal SaaS.

This app currently hosts:

- Platform administration for the SaaS operator.
- Tenant management portals for subscribed waste haulers.
- Customer portal signup, sign-in, customer home, documents, schedules, and service issues.

The product is moving from an HOA-first portal to a tenant-branded customer portal for residential, community/HOA, commercial, and future roll-off service customers. Some folders still use legacy names such as `hoa_management` and `address_registry`; new work should use customer account, community, and service-location language in the UI and domain model.

Current UX priorities:

- CSR-focused ticket queues and ticket detail workflows.
- A consolidated Customers workspace for accounts, residential city/community contexts, and service addresses.
- Customer self-registration through service address match plus email verification.
- A PWA-first customer portal experience for documents, schedules, announcements, and service issues.

## Local Development

Start the local Supabase stack first, then run the Flutter web app with the local Supabase URL and anon key:

```sh
flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 8080 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<local anon key>
```

This starts the server only. Open the app yourself in whichever browser you want to test.

Common local URLs:

- App: `http://127.0.0.1:8080`
- Supabase Studio: `http://127.0.0.1:54323`
- Mailpit: `http://127.0.0.1:54324`
