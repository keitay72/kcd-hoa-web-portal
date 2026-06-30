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

function maybeArray<T>(value: T[] | null | undefined): T[] {
  return Array.isArray(value) ? value : [];
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
    .select("id, account_number, account_type, name, metadata, external_account_ref")
    .eq("id", membership.customer_account_id)
    .maybeSingle();

  if (accountError) return jsonResponse({ error: accountError.message }, 500);
  if (!account) return jsonResponse({ error: "Customer account not found" }, 404);

  const { data: serviceLocation, error: locationError } = await serviceClient
    .from("service_locations")
    .select("id, line1, line2, city, state, postal_code, external_location_ref, metadata")
    .eq("id", membership.service_location_id)
    .maybeSingle();

  if (locationError) return jsonResponse({ error: locationError.message }, 500);

  const metadata = account.metadata ?? {};
  const rawCommunityType =
    typeof metadata.community_type === "string" ? metadata.community_type : "hoa";
  const communityType = rawCommunityType === "city" ? "city" : "hoa";
  const legacyHoaId =
    typeof metadata.legacy_hoa_id === "string"
      ? metadata.legacy_hoa_id
      : account.account_type === "community"
      ? account.external_account_ref
      : null;

  let announcements: unknown[] = [];
  let documents: unknown[] = [];
  let schedules: unknown[] = [];

  if (legacyHoaId) {
    const { data: announcementRows, error: announcementError } =
      await serviceClient
        .from("announcements")
        .select("id, title, body, publish_at")
        .eq("hoa_id", legacyHoaId)
        .eq("status", "published")
        .or(`expire_at.is.null,expire_at.gt.${new Date().toISOString()}`)
        .order("publish_at", { ascending: false })
        .limit(5);
    if (announcementError) {
      return jsonResponse({ error: announcementError.message }, 500);
    }
    announcements = maybeArray(announcementRows);

    const { data: documentRows, error: documentError } = await serviceClient
      .from("documents")
      .select("id, title, category, mime_type, storage_path")
      .eq("hoa_id", legacyHoaId)
      .eq("status", "active")
      .eq("visibility_scope", "resident")
      .order("title", { ascending: true });
    if (documentError) return jsonResponse({ error: documentError.message }, 500);
    documents = maybeArray(documentRows);

    const { data: scheduleRows, error: scheduleError } = await serviceClient
      .from("service_schedules")
      .select("id, service_type, service_day, schedule_rule, route_name, notes")
      .eq("hoa_id", legacyHoaId)
      .eq("status", "active")
      .order("service_type", { ascending: true });
    if (scheduleError) return jsonResponse({ error: scheduleError.message }, 500);
    schedules = maybeArray(scheduleRows);
  }

  const { data: boardRows, error: boardError } = await serviceClient
    .from("customer_memberships")
    .select("id, user_id, is_primary_contact, roles!inner(name, code)")
    .eq("customer_account_id", account.id)
    .is("service_location_id", null)
    .eq("status", "active")
    .order("is_primary_contact", { ascending: false });

  if (boardError) return jsonResponse({ error: boardError.message }, 500);

  let recentTickets: unknown[] = [];
  if (legacyHoaId && membership.service_location_id) {
    const locationMetadata = (serviceLocation as any)?.metadata ?? {};
    const legacyAddressId =
      typeof locationMetadata.legacy_address_id === "string"
        ? locationMetadata.legacy_address_id
        : (serviceLocation as any)?.external_location_ref ?? null;

    if (legacyAddressId) {
      const { data: ticketRows, error: ticketError } = await serviceClient
        .from("tickets")
        .select("id, type, priority, status, subject, description, created_at, updated_at")
        .eq("requester_user_id", userData.user.id)
        .eq("hoa_id", legacyHoaId)
        .eq("address_id", legacyAddressId)
        .order("created_at", { ascending: false })
        .limit(5);

      if (ticketError) return jsonResponse({ error: ticketError.message }, 500);
      recentTickets = maybeArray(ticketRows);
    }
  }

  const boardUserIds = maybeArray(boardRows)
    .map((row: any) => row.user_id)
    .filter((id): id is string => typeof id === "string" && id.length > 0);
  const profilesById = new Map<string, any>();

  if (boardUserIds.length > 0) {
    const { data: profileRows, error: profileError } = await serviceClient
      .from("profiles")
      .select("id, full_name, email, phone")
      .in("id", boardUserIds);

    if (profileError) return jsonResponse({ error: profileError.message }, 500);
    for (const profile of maybeArray(profileRows)) {
      profilesById.set((profile as any).id, profile);
    }
  }

  return jsonResponse({
    account: {
      id: account.id,
      accountNumber: account.account_number,
      accountType: account.account_type,
      name: account.name,
      isCommunityAccount: account.account_type === "community",
      communityType,
    },
    serviceLocation,
    announcements,
    documents,
    schedules,
    recentTickets,
    boardMembers: maybeArray(boardRows).map((row: any) => ({
      id: row.id,
      name:
        profilesById.get(row.user_id)?.full_name ??
          profilesById.get(row.user_id)?.email ??
          "Community contact",
      email: profilesById.get(row.user_id)?.email ?? null,
      phone: profilesById.get(row.user_id)?.phone ?? null,
      roleName: row.roles?.name ?? "Community contact",
      roleCode: row.roles?.code ?? null,
      isPrimaryContact: row.is_primary_contact === true,
    })),
  });
});
