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

async function activateCustomerMembership(
  serviceClient: any,
  verification: {
    id: string;
    tenant_id: string;
    customer_account_id: string;
    service_location_id: string;
  },
  userId: string,
) {
  const { data: customerRole, error: roleError } = await serviceClient
    .from("roles")
    .select("id")
    .eq("code", "customer_user")
    .single();

  if (roleError || !customerRole) {
    return roleError?.message ?? "Customer user role is not configured";
  }

  const now = new Date().toISOString();

  const { error: verificationUpdateError } = await serviceClient
    .from("customer_verifications")
    .update({
      address_matched: true,
      email_verified: true,
      status: "verified",
      verified_at: now,
    })
    .eq("id", verification.id);

  if (verificationUpdateError) {
    return verificationUpdateError.message;
  }

  const membershipPayload = {
    tenant_id: verification.tenant_id,
    user_id: userId,
    customer_account_id: verification.customer_account_id,
    service_location_id: verification.service_location_id,
    role_id: customerRole.id,
    status: "active",
    is_primary_contact: true,
    created_by: userId,
  };

  const { data: existingMembership, error: existingMembershipError } =
    await serviceClient
      .from("customer_memberships")
      .select("id")
      .eq("user_id", userId)
      .eq("customer_account_id", verification.customer_account_id)
      .eq("service_location_id", verification.service_location_id)
      .eq("role_id", customerRole.id)
      .in("status", ["pending", "active"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

  if (existingMembershipError) {
    return existingMembershipError.message;
  }

  const { error: membershipError } = existingMembership
    ? await serviceClient
      .from("customer_memberships")
      .update(membershipPayload)
      .eq("id", existingMembership.id)
    : await serviceClient
      .from("customer_memberships")
      .insert(membershipPayload);

  if (membershipError) {
    return membershipError.message;
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
    .from("customer_verifications")
    .select(
      "id, user_id, tenant_id, customer_account_id, service_location_id, status",
    )
    .eq("user_id", userData.user.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (verificationError) {
    return jsonResponse({ error: verificationError.message }, 500);
  }

  if (!verification) {
    return jsonResponse(
      { error: "Customer verification record not found" },
      404,
    );
  }

  if (verification.status === "verified") {
    return jsonResponse({ verified: true, activationCodeRequired: false });
  }

  if (!verification.customer_account_id || !verification.service_location_id) {
    return jsonResponse({
      error: "Customer verification is missing a service location",
    }, 400);
  }

  const activationCodeRequired = false;

  if (activationCodeRequired) {
    const { error: updateError } = await serviceClient
      .from("customer_verifications")
      .update({ email_verified: true })
      .eq("id", verification.id);

    if (updateError) {
      return jsonResponse({ error: updateError.message }, 500);
    }

    return jsonResponse({ verified: false, activationCodeRequired: true });
  }

  const membershipError = await activateCustomerMembership(
    serviceClient,
    {
      id: verification.id,
      tenant_id: verification.tenant_id,
      customer_account_id: verification.customer_account_id,
      service_location_id: verification.service_location_id,
    },
    userData.user.id,
  );

  if (membershipError) {
    return jsonResponse({ error: membershipError }, 500);
  }

  return jsonResponse({ verified: true, activationCodeRequired: false });
});
