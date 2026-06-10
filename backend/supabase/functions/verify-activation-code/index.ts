import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type VerifyActivationCodeRequest = {
  verificationId?: string;
  addressId?: string;
  code?: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    },
  });
}

async function sha256Hex(value: string) {
  const encoded = new TextEncoder().encode(value.trim());
  const digest = await crypto.subtle.digest('SHA-256', encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return jsonResponse({ ok: true });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: 'Server configuration is missing' }, 500);
  }

  const authHeader = request.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Authentication required' }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: 'Invalid session' }, 401);
  }

  const payload = (await request.json()) as VerifyActivationCodeRequest;
  const verificationId = payload.verificationId?.trim();
  const addressId = payload.addressId?.trim();
  const code = payload.code?.trim();

  if (!verificationId || !addressId || !code) {
    return jsonResponse({ error: 'Verification, address, and activation code are required' }, 400);
  }

  const { data: verification, error: verificationError } = await serviceClient
    .from('residency_verifications')
    .select('id, user_id, hoa_id, address_id, status')
    .eq('id', verificationId)
    .eq('user_id', userData.user.id)
    .eq('address_id', addressId)
    .maybeSingle();

  if (verificationError) {
    return jsonResponse({ error: verificationError.message }, 500);
  }

  if (!verification) {
    return jsonResponse({ error: 'Verification record not found' }, 404);
  }

  if (verification.status === 'verified') {
    return jsonResponse({ verified: true });
  }

  const codeHash = await sha256Hex(code);
  const { data: activationCode, error: codeError } = await serviceClient
    .from('activation_codes')
    .select('id, hoa_id, address_id, code_hash, expires_at, status')
    .eq('address_id', addressId)
    .eq('status', 'active')
    .maybeSingle();

  if (codeError) {
    return jsonResponse({ error: codeError.message }, 500);
  }

  if (!activationCode || activationCode.hoa_id !== verification.hoa_id) {
    return jsonResponse({ error: 'No active activation code found for this address' }, 404);
  }

  if (new Date(activationCode.expires_at).getTime() <= Date.now()) {
    await serviceClient
      .from('activation_codes')
      .update({ status: 'expired' })
      .eq('id', activationCode.id);
    await serviceClient.from('activation_code_events').insert({
      activation_code_id: activationCode.id,
      action: 'expired',
      actor_user_id: userData.user.id,
      reason: 'Activation code expired during resident verification',
    });
    return jsonResponse({ error: 'Activation code expired' }, 400);
  }

  if (activationCode.code_hash !== codeHash) {
    return jsonResponse({ error: 'Invalid activation code' }, 400);
  }

  const { data: residentRole, error: roleError } = await serviceClient
    .from('roles')
    .select('id')
    .eq('code', 'hoa_resident')
    .single();

  if (roleError || !residentRole) {
    return jsonResponse({ error: 'Resident role is not configured' }, 500);
  }

  const now = new Date().toISOString();

  const { error: consumeError } = await serviceClient
    .from('activation_codes')
    .update({
      status: 'consumed',
      consumed_at: now,
      consumed_by: userData.user.id,
    })
    .eq('id', activationCode.id);

  if (consumeError) {
    return jsonResponse({ error: consumeError.message }, 500);
  }

  await serviceClient.from('activation_code_events').insert({
    activation_code_id: activationCode.id,
    action: 'consumed',
    actor_user_id: userData.user.id,
    reason: 'Resident completed activation code verification',
  });

  const { error: verificationUpdateError } = await serviceClient
    .from('residency_verifications')
    .update({
      address_verified: true,
      email_verified: true,
      activation_code_verified: true,
      status: 'verified',
      verified_at: now,
    })
    .eq('id', verification.id);

  if (verificationUpdateError) {
    return jsonResponse({ error: verificationUpdateError.message }, 500);
  }

  const { error: hoaMembershipError } = await serviceClient
    .from('user_hoa_memberships')
    .upsert({
      user_id: userData.user.id,
      hoa_id: verification.hoa_id,
      role_id: residentRole.id,
      status: 'active',
      assigned_by: userData.user.id,
    }, { onConflict: 'user_id,hoa_id,role_id' });

  if (hoaMembershipError) {
    return jsonResponse({ error: hoaMembershipError.message }, 500);
  }

  const { error: addressMembershipError } = await serviceClient
    .from('user_address_memberships')
    .insert({
      user_id: userData.user.id,
      hoa_id: verification.hoa_id,
      address_id: verification.address_id,
      occupancy_type: 'resident',
      is_primary: true,
      is_current: true,
      created_by: userData.user.id,
    });

  if (addressMembershipError && !addressMembershipError.message.includes('duplicate key')) {
    return jsonResponse({ error: addressMembershipError.message }, 500);
  }

  return jsonResponse({ verified: true });
});
