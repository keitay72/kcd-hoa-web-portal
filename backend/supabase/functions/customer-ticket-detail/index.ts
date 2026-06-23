import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type TicketDetailRequest = {
  ticketId?: string;
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

  const payload = (await request.json()) as TicketDetailRequest;
  const ticketId = payload.ticketId?.trim();
  if (!ticketId) return jsonResponse({ error: "Ticket id is required" }, 400);

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

  const { data: ticket, error: ticketError } = await serviceClient
    .from("tickets")
    .select(
      "id, type, priority, status, subject, description, created_at, updated_at, hoa_id, address_id, requester_user_id",
    )
    .eq("id", ticketId)
    .eq("requester_user_id", userData.user.id)
    .maybeSingle();

  if (ticketError) return jsonResponse({ error: ticketError.message }, 500);
  if (!ticket) return jsonResponse({ error: "Ticket not found" }, 404);

  const { data: events, error: eventsError } = await serviceClient
    .from("ticket_events")
    .select("id, ticket_id, actor_user_id, old_status, new_status, note, created_at")
    .eq("ticket_id", ticket.id)
    .order("created_at", { ascending: false });

  if (eventsError) return jsonResponse({ error: eventsError.message }, 500);

  const { data: attachments, error: attachmentsError } = await serviceClient
    .from("ticket_attachments")
    .select("id, ticket_id, uploaded_by, storage_path, mime_type, file_size, scan_status, created_at")
    .eq("ticket_id", ticket.id)
    .neq("scan_status", "blocked")
    .order("created_at", { ascending: false });

  if (attachmentsError) {
    return jsonResponse({ error: attachmentsError.message }, 500);
  }

  const publicEvents = maybeArray(events)
    .filter((event: any) => !String(event.note ?? "").startsWith("[INTERNAL]"))
    .map((event: any) => ({
      id: event.id,
      ticketId: event.ticket_id,
      oldStatus: event.old_status,
      newStatus: event.new_status,
      note: publicNote(event.note),
      createdAt: event.created_at,
      actorLabel:
        event.actor_user_id === userData.user.id ? "You" : "Service team",
    }));

  return jsonResponse({
    ticket: {
      id: ticket.id,
      type: ticket.type,
      priority: ticket.priority,
      status: ticket.status,
      subject: ticket.subject,
      description: ticket.description,
      createdAt: ticket.created_at,
      updatedAt: ticket.updated_at,
    },
    events: publicEvents,
    attachments: maybeArray(attachments).map((attachment: any) => ({
      id: attachment.id,
      ticketId: attachment.ticket_id,
      uploadedBy:
        attachment.uploaded_by === userData.user.id ? "You" : "Service team",
      storagePath: attachment.storage_path,
      mimeType: attachment.mime_type,
      fileSize: attachment.file_size,
      scanStatus: attachment.scan_status,
      createdAt: attachment.created_at,
    })),
  });
});

function publicNote(note: unknown): string | null {
  const value = String(note ?? "").trim();
  if (!value) return null;
  if (value.startsWith("[ASSIGNMENT]")) {
    return "Your issue has been assigned to the service team.";
  }
  if (value.startsWith("[AUTOMATION]")) return null;
  return value;
}
