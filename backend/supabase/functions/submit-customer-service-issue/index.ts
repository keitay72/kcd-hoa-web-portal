import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type SubmitCustomerIssueRequest = {
  type?: string;
  subject?: string;
  description?: string;
};

const validTypes = new Set([
  "missed_pickup",
  "damaged_cart",
  "complaint",
  "service_issue",
]);

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
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration is missing" }, 500);
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "Authentication required" }, 401);

  const payload = (await request.json()) as SubmitCustomerIssueRequest;
  const type = payload.type?.trim() || "service_issue";
  const subject = payload.subject?.trim();
  const description = payload.description?.trim();

  if (!validTypes.has(type)) return jsonResponse({ error: "Invalid issue type" }, 400);
  if (!subject) return jsonResponse({ error: "Subject is required" }, 400);
  if (!description) return jsonResponse({ error: "Description is required" }, 400);

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

  const { data: membership, error: membershipError } = await serviceClient
    .from("customer_memberships")
    .select("customer_account_id, service_location_id")
    .eq("user_id", userData.user.id)
    .eq("status", "active")
    .not("service_location_id", "is", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (membershipError) return jsonResponse({ error: membershipError.message }, 500);
  if (!membership) return jsonResponse({ error: "Customer access not found" }, 404);

  const { data: account, error: accountError } = await serviceClient
    .from("customer_accounts")
    .select("id, account_type, metadata, external_account_ref")
    .eq("id", membership.customer_account_id)
    .maybeSingle();
  if (accountError) return jsonResponse({ error: accountError.message }, 500);
  if (!account) return jsonResponse({ error: "Customer account not found" }, 404);

  const { data: serviceLocation, error: locationError } = await serviceClient
    .from("service_locations")
    .select("id, external_location_ref, metadata")
    .eq("id", membership.service_location_id)
    .maybeSingle();
  if (locationError) return jsonResponse({ error: locationError.message }, 500);
  if (!serviceLocation) {
    return jsonResponse({ error: "Service location not found" }, 404);
  }

  const accountMetadata = account.metadata ?? {};
  const locationMetadata = serviceLocation.metadata ?? {};
  const hoaId =
    typeof accountMetadata.legacy_hoa_id === "string"
      ? accountMetadata.legacy_hoa_id
      : account.account_type === "community"
      ? account.external_account_ref
      : null;
  const addressId =
    typeof locationMetadata.legacy_address_id === "string"
      ? locationMetadata.legacy_address_id
      : serviceLocation.external_location_ref;

  if (!hoaId || !addressId) {
    return jsonResponse({
      error:
        "Service issue submission is not configured for this customer account yet",
    }, 400);
  }

  const { data: existingAddressMembership, error: existingMembershipError } =
    await serviceClient
      .from("user_address_memberships")
      .select("id")
      .eq("user_id", userData.user.id)
      .eq("hoa_id", hoaId)
      .eq("address_id", addressId)
      .eq("is_current", true)
      .limit(1)
      .maybeSingle();

  if (existingMembershipError) {
    return jsonResponse({ error: existingMembershipError.message }, 500);
  }

  if (!existingAddressMembership) {
    const { error: addressMembershipError } = await serviceClient
      .from("user_address_memberships")
      .insert({
        user_id: userData.user.id,
        hoa_id: hoaId,
        address_id: addressId,
        occupancy_type: "resident",
        is_primary: true,
        is_current: true,
        created_by: userData.user.id,
      });

    if (addressMembershipError) {
      return jsonResponse({ error: addressMembershipError.message }, 500);
    }
  }

  const { data: ticketId, error: ticketError } = await userClient.rpc(
    "submit_resident_service_issue",
    {
      _hoa_id: hoaId,
      _address_id: addressId,
      _type: type,
      _subject: subject,
      _description: description,
    },
  );

  if (ticketError) return jsonResponse({ error: ticketError.message }, 500);

  return jsonResponse({ ticketId });
});
