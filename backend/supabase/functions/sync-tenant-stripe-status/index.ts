import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type SyncRequest = { tenant_id?: string; subscription_id?: string };
type CallerResult = | { user: { id: string }; error?: never } | { error: string; user?: never };

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizeString(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

async function requireCallerUser(request: Request, supabaseUrl: string, anonKey: string): Promise<CallerResult> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader) return { error: 'Missing Authorization header' };
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return { error: 'Invalid or expired session' };
  return { user: data.user };
}

async function callerCanManageBilling(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('user_global_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .in('roles.code', ['platform_owner', 'platform_admin', 'platform_sales'])
    .limit(1);
  if (error) throw error;
  if (Array.isArray(data) && data.length > 0) return true;

  const { data: legacy, error: legacyError } = await supabase
    .from('user_platform_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .in('roles.code', ['sys_admin', 'mgmt'])
    .limit(1);
  if (legacyError) throw legacyError;
  return Array.isArray(legacy) && legacy.length > 0;
}

async function fetchStripeSubscription(stripeSecretKey: string, stripeSubscriptionId: string) {
  const response = await fetch(`https://api.stripe.com/v1/subscriptions/${stripeSubscriptionId}`, {
    headers: { Authorization: `Bearer ${stripeSecretKey}` },
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message ?? 'Unable to fetch Stripe subscription.');
  }
  return body;
}

async function updateSubscriptionFromStripe(
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

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse({ success: false, message: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ success: false, message: 'Supabase Edge Function environment is not configured.' }, 500);
  }
  if (!stripeSecretKey) {
    return jsonResponse({ success: false, code: 'stripe_not_configured', message: 'Stripe is not configured. Set STRIPE_SECRET_KEY before syncing.' }, 501);
  }

  const caller = await requireCallerUser(request, supabaseUrl, anonKey);
  if (caller.error) return jsonResponse({ success: false, message: caller.error }, 401);
  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
  if (!(await callerCanManageBilling(supabase, caller.user.id))) {
    return jsonResponse({ success: false, message: 'Only platform billing users may sync tenant subscriptions.' }, 403);
  }

  const payload = await request.json().catch(() => ({})) as SyncRequest;
  const tenantId = normalizeString(payload.tenant_id);
  const subscriptionId = normalizeString(payload.subscription_id);
  if (!tenantId || !subscriptionId) {
    return jsonResponse({ success: false, message: 'tenant_id and subscription_id are required.' }, 400);
  }

  const { data: subscription, error } = await supabase
    .from('tenant_subscriptions')
    .select('id, stripe_subscription_id')
    .eq('id', subscriptionId)
    .eq('tenant_id', tenantId)
    .maybeSingle();
  if (error) throw error;
  if (!subscription) return jsonResponse({ success: false, message: 'Tenant subscription was not found.' }, 404);
  if (!subscription.stripe_subscription_id) {
    return jsonResponse({ success: false, code: 'stripe_subscription_missing', message: 'This tenant subscription does not have a Stripe subscription ID yet.' }, 400);
  }

  try {
    const stripeSubscription = await fetchStripeSubscription(stripeSecretKey, subscription.stripe_subscription_id);
    await updateSubscriptionFromStripe(supabase, subscriptionId, stripeSubscription);
    return jsonResponse({ success: true, message: 'Stripe subscription status synced.' });
  } catch (error) {
    return jsonResponse({ success: false, message: error instanceof Error ? error.message : 'Unable to sync Stripe subscription.' }, 502);
  }
});
