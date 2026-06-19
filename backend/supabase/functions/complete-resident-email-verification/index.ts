import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

async function activateResidentMembership(
  serviceClient: any,
  verification: {
    id: string;
    hoa_id: string;
    address_id: string;
  },
  userId: string,
) {
  const { data: residentRole, error: roleError } = await serviceClient
    .from("roles")
    .select("id")
    .eq("code", "hoa_resident")
    .single();

  if (roleError || !residentRole) {
    return roleError?.message ?? "Resident role is not configured";
  }

  const now = new Date().toISOString();

  const { error: verificationUpdateError } = await serviceClient
    .from("residency_verifications")
    .update({
      address_verified: true,
      email_verified: true,
      activation_code_verified: true,
      status: "verified",
      verified_at: now,
    })
    .eq("id", verification.id);

  if (verificationUpdateError) {
    return verificationUpdateError.message;
  }

  const { error: hoaMembershipError } = await serviceClient
    .from("user_hoa_memberships")
    .upsert({
      user_id: userId,
      hoa_id: verification.hoa_id,
      role_id: residentRole.id,
      status: "active",
      assigned_by: userId,
    }, { onConflict: "user_id,hoa_id,role_id" });

  if (hoaMembershipError) {
    return hoaMembershipError.message;
  }

  const { error: addressMembershipError } = await serviceClient
    .from("user_address_memberships")
    .insert({
      user_id: userId,
      hoa_id: verification.hoa_id,
      address_id: verification.address_id,
      occupancy_type: "resident",
      is_primary: true,
      is_current: true,
      created_by: userId,
    });

  if (
    addressMembershipError &&
    !addressMembershipError.message.includes("duplicate key")
  ) {
    return addressMembershipError.message;
  }

  return null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return jsonResponse({ ok: true });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration is missing" }, 500);
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Authentication required" }, 401);
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
    return jsonResponse({ error: "Invalid session" }, 401);
  }

  const { data: verification, error: verificationError } = await serviceClient
    .from("residency_verifications")
    .select("id, user_id, hoa_id, address_id, status")
    .eq("user_id", userData.user.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (verificationError) {
    return jsonResponse({ error: verificationError.message }, 500);
  }

  if (!verification) {
    return jsonResponse(
      { error: "Resident verification record not found" },
      404,
    );
  }

  if (verification.status === "verified") {
    return jsonResponse({ verified: true, activationCodeRequired: false });
  }

  if (!verification.address_id) {
    return jsonResponse({
      error: "Resident verification is missing an address",
    }, 400);
  }

  const { data: activationRequired, error: activationSettingError } =
    await serviceClient
      .rpc("resident_activation_code_required", {
        _hoa_id: verification.hoa_id,
      });

  if (activationSettingError) {
    return jsonResponse({ error: activationSettingError.message }, 500);
  }

  const activationCodeRequired = activationRequired !== false;

  if (activationCodeRequired) {
    const { error: updateError } = await serviceClient
      .from("residency_verifications")
      .update({ email_verified: true })
      .eq("id", verification.id);

    if (updateError) {
      return jsonResponse({ error: updateError.message }, 500);
    }

    return jsonResponse({ verified: false, activationCodeRequired: true });
  }

  const membershipError = await activateResidentMembership(
    serviceClient,
    {
      id: verification.id,
      hoa_id: verification.hoa_id,
      address_id: verification.address_id,
    },
    userData.user.id,
  );

  if (membershipError) {
    return jsonResponse({ error: membershipError }, 500);
  }

  return jsonResponse({ verified: true, activationCodeRequired: false });
});
