import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type VerifyAddressRequest = {
  tenantCode?: string;
  line1?: string;
  line2?: string;
  city?: string;
  state?: string;
  postalCode?: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    },
  });
}

function normalizePart(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '');
}

function normalizeLegacyPart(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function normalizePostalCode(value: string) {
  return value.trim().toUpperCase().replace(/\s+/g, '');
}

function normalizeAddress(
  input: VerifyAddressRequest,
  normalizer: (value: string) => string = normalizePart,
) {
  return [
    input.line1,
    input.line2,
    input.city,
    input.state?.trim().toUpperCase(),
    input.postalCode == null ? undefined : normalizePostalCode(input.postalCode),
  ]
    .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
    .map(normalizer)
    .join('|');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return jsonResponse({ ok: true });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server configuration is missing' }, 500);
  }

  const payload = (await request.json()) as VerifyAddressRequest;
  const tenantCode = payload.tenantCode?.trim().toUpperCase();
  const normalizedKey = normalizeAddress(payload);
  const legacyNormalizedKey = normalizeAddress(payload, normalizeLegacyPart);
  const normalizedKeys = Array.from(new Set([normalizedKey, legacyNormalizedKey].filter(Boolean)));

  if (!tenantCode) {
    return jsonResponse({ error: 'Tenant code is required' }, 400);
  }

  if (!normalizedKey) {
    return jsonResponse({ error: 'Address is required' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: tenant, error: tenantError } = await supabase
    .from('platform_tenants')
    .select('id, code, name')
    .eq('code', tenantCode)
    .maybeSingle();

  if (tenantError) {
    return jsonResponse({ error: tenantError.message }, 500);
  }

  if (!tenant) {
    return jsonResponse({ verified: false }, 200);
  }

  const { data, error } = await supabase
    .from('service_locations')
    .select('id, customer_account_id, line1, line2, city, state, postal_code, status, customer_accounts!inner(name, account_number, account_type, tenant_id)')
    .in('normalized_key', normalizedKeys)
    .eq('status', 'active')
    .eq('customer_accounts.tenant_id', tenant.id)
    .limit(1)
    .maybeSingle();

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  if (!data) {
    return jsonResponse({ verified: false }, 200);
  }

  return jsonResponse({
    verified: true,
    address: {
      id: data.id,
      hoaId: data.customer_account_id,
      serviceLocationId: data.id,
      customerAccountId: data.customer_account_id,
      line1: data.line1,
      line2: data.line2,
      city: data.city,
      state: data.state,
      postalCode: data.postal_code,
      hoaName: data.customer_accounts?.name ?? null,
      hoaCode: data.customer_accounts?.account_number ?? null,
      customerAccountName: data.customer_accounts?.name ?? null,
      customerAccountNumber: data.customer_accounts?.account_number ?? null,
      customerAccountType: data.customer_accounts?.account_type ?? null,
      tenantName: tenant.name,
      tenantCode: tenant.code,
    },
  });
});
