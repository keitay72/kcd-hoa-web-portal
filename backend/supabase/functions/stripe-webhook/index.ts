import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const encoder = new TextEncoder();

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function timingSafeEqual(a: Uint8Array, b: Uint8Array) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i += 1) result |= a[i] ^ b[i];
  return result === 0;
}

function hexToBytes(hex: string) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i += 1) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

async function hmacSha256(secret: string, payload: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function verifyStripeSignature(rawBody: string, signatureHeader: string | null, webhookSecret: string) {
  if (!signatureHeader) return false;
  const parts = Object.fromEntries(
    signatureHeader.split(',').map((part) => {
      const [key, value] = part.split('=');
      return [key, value];
    }),
  );
  const timestamp = parts.t;
  const signature = parts.v1;
  if (!timestamp || !signature) return false;
  const expected = await hmacSha256(webhookSecret, `${timestamp}.${rawBody}`);
  return timingSafeEqual(hexToBytes(expected), hexToBytes(signature));
}

function metadataValue(value: unknown) {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : null;
}

async function updateTenantSubscription(
  supabase: SupabaseClient,
  subscriptionId: string,
  stripeSubscription: Record<string, unknown>,
) {
  const currentPeriodStart = typeof stripeSubscription.current_period_start === 'number'
    ? new Date(stripeSubscription.current_period_start * 1000).toISOString()
    : null;
  const currentPeriodEnd = typeof stripeSubscription.current_period_end === 'number'
    ? new Date(stripeSubscription.current_period_end * 1000).toISOString()
    : null;
  const trialEndsAt = typeof stripeSubscription.trial_end === 'number'
    ? new Date(stripeSubscription.trial_end * 1000).toISOString()
    : null;
  const cancelledAt = typeof stripeSubscription.canceled_at === 'number'
    ? new Date(stripeSubscription.canceled_at * 1000).toISOString()
    : null;

  const { error } = await supabase
    .from('tenant_subscriptions')
    .update({
      status: stripeSubscription.status,
      stripe_customer_id: stripeSubscription.customer,
      stripe_subscription_id: stripeSubscription.id,
      current_period_start: currentPeriodStart,
      current_period_end: currentPeriodEnd,
      trial_ends_at: trialEndsAt,
      cancelled_at: cancelledAt,
    })
    .eq('id', subscriptionId);
  if (error) throw error;
}

async function handleCheckoutCompleted(supabase: SupabaseClient, session: Record<string, unknown>) {
  const metadata = session.metadata as Record<string, unknown> | null;
  const subscriptionId = metadataValue(metadata?.tenant_subscription_id);
  if (!subscriptionId) return;

  const { error } = await supabase
    .from('tenant_subscriptions')
    .update({
      status: 'active',
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
    })
    .eq('id', subscriptionId);
  if (error) throw error;
}

async function handleSubscriptionEvent(supabase: SupabaseClient, subscription: Record<string, unknown>) {
  const metadata = subscription.metadata as Record<string, unknown> | null;
  const metadataSubscriptionId = metadataValue(metadata?.tenant_subscription_id);
  if (metadataSubscriptionId) {
    await updateTenantSubscription(supabase, metadataSubscriptionId, subscription);
    return;
  }

  const stripeSubscriptionId = metadataValue(subscription.id);
  if (!stripeSubscriptionId) return;
  const { data, error } = await supabase
    .from('tenant_subscriptions')
    .select('id')
    .eq('stripe_subscription_id', stripeSubscriptionId)
    .maybeSingle();
  if (error) throw error;
  if (data?.id) await updateTenantSubscription(supabase, data.id, subscription);
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return jsonResponse({ received: false, message: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ received: false, message: 'Supabase Edge Function environment is not configured.' }, 500);
  }
  if (!webhookSecret) {
    return jsonResponse({ received: false, code: 'stripe_not_configured', message: 'Stripe webhook is not configured. Set STRIPE_WEBHOOK_SECRET.' }, 501);
  }

  const rawBody = await request.text();
  const isValid = await verifyStripeSignature(rawBody, request.headers.get('stripe-signature'), webhookSecret);
  if (!isValid) return jsonResponse({ received: false, message: 'Invalid Stripe signature.' }, 400);

  const event = JSON.parse(rawBody) as { type: string; data: { object: Record<string, unknown> } };
  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  try {
    if (event.type === 'checkout.session.completed') {
      await handleCheckoutCompleted(supabase, event.data.object);
    }
    if (
      event.type === 'customer.subscription.created' ||
      event.type === 'customer.subscription.updated' ||
      event.type === 'customer.subscription.deleted'
    ) {
      await handleSubscriptionEvent(supabase, event.data.object);
    }
    return jsonResponse({ received: true });
  } catch (error) {
    return jsonResponse({ received: false, message: error instanceof Error ? error.message : 'Webhook handling failed.' }, 500);
  }
});
