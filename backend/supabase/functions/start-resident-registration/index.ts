import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type StartRegistrationRequest = {
  tenantCode?: string;
  userId?: string;
  fullName?: string;
  email?: string;
  addressId?: string;
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

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return jsonResponse({ ok: true });
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server configuration is missing' }, 500);
  }

  const payload = (await request.json()) as StartRegistrationRequest;
  const tenantCode = payload.tenantCode?.trim().toUpperCase();
  const userId = payload.userId?.trim();
  const email = payload.email?.trim().toLowerCase();
  const fullName = payload.fullName?.trim();
  const addressId = payload.addressId?.trim();

  if (!tenantCode || !userId || !email || !fullName || !addressId) {
    return jsonResponse({ error: 'Tenant, user, name, email, and address are required' }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: tenant, error: tenantError } = await supabase
    .from('platform_tenants')
    .select('id, code')
    .eq('code', tenantCode)
    .maybeSingle();

  if (tenantError) return jsonResponse({ error: tenantError.message }, 500);
  if (!tenant) return jsonResponse({ error: 'Tenant not found' }, 404);

  const { data: address, error: addressError } = await supabase
    .from('hoa_addresses')
    .select('id, hoa_id, is_active, hoa_communities!inner(tenant_id)')
    .eq('id', addressId)
    .eq('is_active', true)
    .eq('hoa_communities.tenant_id', tenant.id)
    .maybeSingle();

  if (addressError) return jsonResponse({ error: addressError.message }, 500);
  if (!address) return jsonResponse({ error: 'Address not found in this portal' }, 404);

  const { error: profileError } = await supabase.from('profiles').upsert({
    id: userId,
    email,
    full_name: fullName,
    status: 'active',
  }, { onConflict: 'id' });

  if (profileError) return jsonResponse({ error: profileError.message }, 500);

  const { data: verification, error: verificationError } = await supabase
    .from('residency_verifications')
    .upsert({
      user_id: userId,
      hoa_id: address.hoa_id,
      address_id: address.id,
      address_verified: false,
      email_verified: false,
      activation_code_verified: false,
      status: 'pending',
      verified_at: null,
    }, { onConflict: 'user_id,hoa_id' })
    .select('id, user_id, hoa_id, address_id, status')
    .single();

  if (verificationError) return jsonResponse({ error: verificationError.message }, 500);

  return jsonResponse({ verification });
});
