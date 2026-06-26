import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

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
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return jsonResponse({ ok: true });
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration is missing" }, 500);
  }

  const payload = (await request.json()) as StartRegistrationRequest;
  const tenantCode = payload.tenantCode?.trim().toUpperCase();
  const userId = payload.userId?.trim();
  const email = payload.email?.trim().toLowerCase();
  const fullName = payload.fullName?.trim();
  const addressId = payload.addressId?.trim();

  if (!tenantCode || !userId || !email || !addressId) {
    return jsonResponse({
      error: "Tenant, user, email, and address are required",
    }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: tenant, error: tenantError } = await supabase
    .from("platform_tenants")
    .select("id, code")
    .eq("code", tenantCode)
    .maybeSingle();

  if (tenantError) return jsonResponse({ error: tenantError.message }, 500);
  if (!tenant) return jsonResponse({ error: "Tenant not found" }, 404);

  const { data: serviceLocation, error: locationError } = await supabase
    .from("service_locations")
    .select(
      "id, customer_account_id, status, customer_accounts!inner(tenant_id)",
    )
    .eq("id", addressId)
    .eq("status", "active")
    .eq("customer_accounts.tenant_id", tenant.id)
    .maybeSingle();

  if (locationError) return jsonResponse({ error: locationError.message }, 500);
  if (!serviceLocation) {
    return jsonResponse({ error: "Address not found in this portal" }, 404);
  }

  const { error: profileError } = await supabase.from("profiles").upsert({
    id: userId,
    email,
    full_name: fullName || null,
    status: "active",
  }, { onConflict: "id" });

  if (profileError) {
    if (
      profileError.message.includes("profiles_email_key") ||
      profileError.message.includes("duplicate key")
    ) {
      return jsonResponse({
        error:
          "An account already exists for this email. Please sign in instead.",
      }, 409);
    }
    return jsonResponse({ error: profileError.message }, 500);
  }

  const verificationPayload = {
    tenant_id: tenant.id,
    user_id: userId,
    email,
    customer_account_id: serviceLocation.customer_account_id,
    service_location_id: serviceLocation.id,
    verification_method: "address_email",
    address_matched: true,
    email_verified: false,
    status: "email_sent",
    verified_at: null,
    metadata: {
      signup_source: "customer_portal",
      full_name: fullName || null,
    },
  };

  const { data: existingVerification, error: existingVerificationError } =
    await supabase
      .from("customer_verifications")
      .select("id")
      .eq("user_id", userId)
      .eq("service_location_id", serviceLocation.id)
      .in("status", ["pending", "email_sent", "verified"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

  if (existingVerificationError) {
    return jsonResponse({ error: existingVerificationError.message }, 500);
  }

  const verificationQuery = existingVerification
    ? supabase
        .from("customer_verifications")
        .update(verificationPayload)
        .eq("id", existingVerification.id)
    : supabase
        .from("customer_verifications")
        .insert(verificationPayload);

  const { data: verification, error: verificationError } =
    await verificationQuery
      .select("id, user_id, customer_account_id, service_location_id, status")
      .single();

  if (verificationError) {
    return jsonResponse({ error: verificationError.message }, 500);
  }

  return jsonResponse({ verification });
});
