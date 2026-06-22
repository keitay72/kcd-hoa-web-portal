# Stripe Setup for Customer Portal SaaS Billing

The platform is Stripe-ready, but safe to run without Stripe keys. Until secrets are configured, checkout and sync actions return clear `Stripe is not configured` messages.

Billing direction is defined in `docs/adr/0002-customer-portal-saas-product-direction.md`: paid tiers should include the full core customer portal feature set and differ by active customer/service-location capacity, with overages for modest growth above a tier.

## Required Stripe Values

Set these as Supabase Edge Function secrets:

```bash
npx supabase secrets set STRIPE_SECRET_KEY="sk_test_..."
npx supabase secrets set STRIPE_WEBHOOK_SECRET="whsec_..."
npx supabase secrets set STRIPE_CHECKOUT_SUCCESS_URL="http://192.168.0.141:8080/admin/tenants"
npx supabase secrets set STRIPE_CHECKOUT_CANCEL_URL="http://192.168.0.141:8080/admin/tenants"
```

Use production URLs and live keys only after test-mode billing is proven end to end.

## Functions

Deploy from the `backend` directory:

```bash
npx supabase functions deploy create-tenant-checkout-session
npx supabase functions deploy sync-tenant-stripe-status
npx supabase functions deploy stripe-webhook
```

## Stripe Products and Prices

Create products/prices in Stripe test mode, then paste each Stripe `price_...` value into the Admin Web App:

`Plans & Add-Ons` -> plan -> price -> `Stripe price ID`

## Webhook Events

Configure Stripe webhook endpoint to point at:

```text
https://<project-ref>.functions.supabase.co/stripe-webhook
```

Subscribe to:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

## Current Behavior

- Platform Owner/Admin can create plans and prices.
- Platform Owner/Admin can assign a tenant subscription.
- Checkout uses the selected subscription price's Stripe Price ID.
- Webhook sync updates `tenant_subscriptions` from Stripe.
- Manual sync is available for test/debug workflows.
