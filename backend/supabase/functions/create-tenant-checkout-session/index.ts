import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type CheckoutRequest = {
  tenant_id?: string;
  subscription_id?: string;
};

type CallerResult =
  | { user: { id: string }; error?: never }
  | { error: string; user?: never };

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
  const { data: globalRoles, error: globalError } = await supabase
    .from('user_global_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .in('roles.code', ['platform_owner', 'platform_admin', 'platform_sales'])
    .limit(1);
  if (globalError) throw globalError;
  if (Array.isArray(globalRoles) && globalRoles.length > 0) return true;

  const { data: legacyRoles, error: legacyError } = await supabase
    .from('user_platform_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .in('roles.code', ['sys_admin', 'mgmt'])
    .limit(1);
  if (legacyError) throw legacyError;
  return Array.isArray(legacyRoles) && legacyRoles.length > 0;
}

async function tenantSubscription(supabase: SupabaseClient, tenantId: string, subscriptionId: string) {
  const { data, error } = await supabase
    .from('tenant_subscriptions')
    .select('*, platform_tenants(name, code), subscription_plan_prices(stripe_price_id)')
    .eq('id', subscriptionId)
    .eq('tenant_id', tenantId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function primaryBillingContact(supabase: SupabaseClient, tenantId: string) {
  const { data, error } = await supabase
    .from('tenant_billing_contacts')
    .select('name, email')
    .eq('tenant_id', tenantId)
    .order('is_primary', { ascending: false })
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function createCheckoutSession(stripeSecretKey: string, params: URLSearchParams) {
  const response = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params,
  });

  const body = await response.json();
  if (!response.ok) {
    const message = body?.error?.message ?? 'Stripe checkout session creation failed';
    throw new Error(message);
  }
  return body;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse({ success: false, message: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
  const successUrl = Deno.env.get('STRIPE_CHECKOUT_SUCCESS_URL');
  const cancelUrl = Deno.env.get('STRIPE_CHECKOUT_CANCEL_URL');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ success: false, message: 'Supabase Edge Function environment is not configured.' }, 500);
  }
  if (!stripeSecretKey) {
    return jsonResponse({ success: false, code: 'stripe_not_configured', message: 'Stripe is not configured. Set STRIPE_SECRET_KEY before starting checkout.' }, 501);
  }
  if (!successUrl || !cancelUrl) {
    return jsonResponse({ success: false, code: 'stripe_redirects_not_configured', message: 'Stripe checkout redirects are not configured. Set STRIPE_CHECKOUT_SUCCESS_URL and STRIPE_CHECKOUT_CANCEL_URL.' }, 501);
  }

  const caller = await requireCallerUser(request, supabaseUrl, anonKey);
  if (caller.error) return jsonResponse({ success: false, message: caller.error }, 401);

  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
  if (!(await callerCanManageBilling(supabase, caller.user.id))) {
    return jsonResponse({ success: false, message: 'Only platform billing users may start tenant checkout.' }, 403);
  }

  const payload = await request.json().catch(() => ({})) as CheckoutRequest;
  const tenantId = normalizeString(payload.tenant_id);
  const subscriptionId = normalizeString(payload.subscription_id);
  if (!tenantId || !subscriptionId) {
    return jsonResponse({ success: false, message: 'tenant_id and subscription_id are required.' }, 400);
  }

  const subscription = await tenantSubscription(supabase, tenantId, subscriptionId);
  if (!subscription) return jsonResponse({ success: false, message: 'Tenant subscription was not found.' }, 404);

  const stripePriceId = subscription.subscription_plan_prices?.stripe_price_id;
  if (!stripePriceId) {
    return jsonResponse({ success: false, code: 'stripe_price_missing', message: 'Selected subscription price does not have a Stripe price ID yet.' }, 400);
  }

  const billingContact = await primaryBillingContact(supabase, tenantId);
  const tenant = subscription.platform_tenants;
  const params = new URLSearchParams();
  params.set('mode', 'subscription');
  params.set('line_items[0][price]', stripePriceId);
  params.set('line_items[0][quantity]', '1');
  params.set('success_url', successUrl);
  params.set('cancel_url', cancelUrl);
  params.set('metadata[tenant_id]', tenantId);
  params.set('metadata[tenant_subscription_id]', subscriptionId);
  params.set('metadata[tenant_name]', tenant?.name ?? tenantId);
  params.set('subscription_data[metadata][tenant_id]', tenantId);
  params.set('subscription_data[metadata][tenant_subscription_id]', subscriptionId);
  if (billingContact?.email) params.set('customer_email', billingContact.email);

  try {
    const session = await createCheckoutSession(stripeSecretKey, params);
    return jsonResponse({
      success: true,
      checkout_url: session.url,
      checkout_session_id: session.id,
      message: 'Checkout session created.',
    });
  } catch (error) {
    return jsonResponse({ success: false, message: error instanceof Error ? error.message : 'Unable to create Stripe checkout session.' }, 502);
  }
});
