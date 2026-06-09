import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type InviteAdminUserRequest = {
  email?: string;
  first_name?: string;
  middle_name?: string | null;
  last_name?: string;
  phone?: string | null;
  role?: string;
  role_code?: string;
  tenant_id?: string | null;
  hoa_id?: string | null;
};

type JsonBody = Record<string, unknown>;

type ParsedInvite = {
  email: string;
  firstName: string;
  middleName: string | null;
  lastName: string;
  fullName: string;
  phone: string;
  role: string;
  tenantId: string | null;
  hoaId: string | null;
  isPlatformRole: boolean;
};

type ParseResult =
  | { ok: true; value: ParsedInvite }
  | { ok: false; error: string };

type CallerResult =
  | { user: { id: string }; error?: never }
  | { error: string; user?: never };

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const platformRoles = new Set(['sys_admin', 'mgmt', 'csr', 'dispatch']);
const hoaRoles = new Set(['hoa_manager', 'hoa_board', 'resident']);
const namePattern = /^[A-Za-z][A-Za-z .'-]*$/;
const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function badRequest(message: string) {
  return jsonResponse({ success: false, message }, 400);
}

function serverError(message: string) {
  return jsonResponse({ success: false, message }, 500);
}

function unauthorized(message = 'Unauthorized') {
  return jsonResponse({ success: false, message }, 401);
}

function forbidden(message = 'Only sys_admin users may invite users') {
  return jsonResponse({ success: false, message }, 403);
}

function normalizeString(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function nullableString(value: unknown) {
  const normalized = normalizeString(value);
  return normalized.length === 0 ? null : normalized;
}

function phoneDigits(value: unknown) {
  return normalizeString(value).replace(/\D/g, '');
}

function fullName(firstName: string, middleName: string | null, lastName: string) {
  return [firstName, middleName, lastName]
    .filter((value): value is string => typeof value === 'string' && value.trim().length > 0)
    .join(' ');
}

function validateName(value: string, label: string, required = true) {
  if (!value) return required ? `${label} is required` : null;
  if (!namePattern.test(value)) {
    return `${label} may only include letters, spaces, apostrophes, hyphens, and periods`;
  }
  return null;
}

function parsePayload(payload: InviteAdminUserRequest): ParseResult {
  const email = normalizeString(payload.email).toLowerCase();
  const firstName = normalizeString(payload.first_name);
  const middleName = nullableString(payload.middle_name);
  const lastName = normalizeString(payload.last_name);
  const phone = phoneDigits(payload.phone);
  const role = normalizeString(payload.role ?? payload.role_code);
  const tenantId = nullableString(payload.tenant_id);
  const hoaId = nullableString(payload.hoa_id);

  if (!emailPattern.test(email)) return { ok: false, error: 'A valid email is required' };

  const firstNameError = validateName(firstName, 'First name');
  if (firstNameError) return { ok: false, error: firstNameError };

  const middleNameError = validateName(middleName ?? '', 'Middle name', false);
  if (middleNameError) return { ok: false, error: middleNameError };

  const lastNameError = validateName(lastName, 'Last name');
  if (lastNameError) return { ok: false, error: lastNameError };

  if (phone.length !== 10) return { ok: false, error: 'Phone must be a 10-digit US phone number' };
  if (!platformRoles.has(role) && !hoaRoles.has(role)) return { ok: false, error: 'Role is invalid' };
  if (platformRoles.has(role) && hoaId) return { ok: false, error: 'KC staff roles must not include hoa_id' };
  if (hoaRoles.has(role) && !hoaId) return { ok: false, error: 'HOA roles require hoa_id' };

  return {
    ok: true,
    value: {
      email,
      firstName,
      middleName,
      lastName,
      fullName: fullName(firstName, middleName, lastName),
      phone,
      role,
      tenantId,
      hoaId,
      isPlatformRole: platformRoles.has(role),
    },
  };
}

async function findAuthUserByEmail(supabase: SupabaseClient, email: string) {
  const target = email.toLowerCase();
  const perPage = 1000;

  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) throw error;

    const user = data.users.find((item) => item.email?.toLowerCase() === target);
    if (user) return user;
    if (data.users.length < perPage) return null;
  }

  throw new Error('Unable to search all Auth users; user list exceeded safety page limit');
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

async function callerIsSysAdmin(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('user_platform_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .eq('roles.code', 'sys_admin')
    .limit(1);

  if (error) throw error;
  return Array.isArray(data) && data.length > 0;
}

async function primaryTenantId(supabase: SupabaseClient) {
  const { data, error } = await supabase
    .from('platform_tenants')
    .select('id')
    .eq('is_primary', true)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data?.id as string | undefined;
}

async function roleIdForCode(supabase: SupabaseClient, role: string) {
  const { data, error } = await supabase
    .from('roles')
    .select('id')
    .eq('code', role)
    .maybeSingle();

  if (error) throw error;
  return data?.id as number | undefined;
}

async function ensureTenantExists(supabase: SupabaseClient, tenantId: string) {
  const { data, error } = await supabase
    .from('platform_tenants')
    .select('id')
    .eq('id', tenantId)
    .maybeSingle();

  if (error) throw error;
  return Boolean(data);
}

async function ensureHoaExists(supabase: SupabaseClient, hoaId: string) {
  const { data, error } = await supabase
    .from('hoa_communities')
    .select('id')
    .eq('id', hoaId)
    .maybeSingle();

  if (error) throw error;
  return Boolean(data);
}

async function inviteOrUpdateAuthUser(
  supabase: SupabaseClient,
  input: ParsedInvite,
  redirectTo: string | undefined,
) {
  const existingUser = await findAuthUserByEmail(supabase, input.email);
  const metadata = {
    first_name: input.firstName,
    middle_name: input.middleName,
    last_name: input.lastName,
    full_name: input.fullName,
    phone: input.phone,
    invited_role: input.role,
  };

  if (existingUser) {
    const { data, error } = await supabase.auth.admin.updateUserById(existingUser.id, {
      email: input.email,
      user_metadata: {
        ...(existingUser.user_metadata ?? {}),
        ...metadata,
      },
    });
    if (error) throw error;
    return { user: data.user, invited: false };
  }

  const { data, error } = await supabase.auth.admin.inviteUserByEmail(input.email, {
    data: metadata,
    redirectTo,
  });

  if (error) throw error;
  return { user: data.user, invited: true };
}

async function writeAuditLog(
  supabase: SupabaseClient,
  actorUserId: string,
  invitedUserId: string,
  input: ParsedInvite,
  request: Request,
) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null;
  const userAgent = request.headers.get('user-agent');

  const { error } = await supabase.from('admin_audit_logs').insert({
    actor_user_id: actorUserId,
    hoa_id: input.hoaId,
    action: 'invite_admin_user',
    entity_type: 'profile',
    entity_id: invitedUserId,
    after_json: {
      email: input.email,
      full_name: input.fullName,
      phone: input.phone,
      role: input.role,
      tenant_id: input.tenantId,
      hoa_id: input.hoaId,
    } as JsonBody,
    ip,
    user_agent: userAgent,
  });

  if (error) throw error;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return jsonResponse({ ok: true });
  if (request.method !== 'POST') return jsonResponse({ success: false, message: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const redirectTo = Deno.env.get('ADMIN_INVITE_REDIRECT_URL') || undefined;

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return serverError('Server configuration is missing');
  }

  let payload: InviteAdminUserRequest;
  try {
    payload = (await request.json()) as InviteAdminUserRequest;
  } catch (_) {
    return badRequest('Invalid JSON body');
  }

  const parsed = parsePayload(payload);
  if (!parsed.ok) return badRequest(parsed.error);
  const input = parsed.value;

  const caller = await requireCallerUser(request, supabaseUrl, anonKey);
  if ('error' in caller) return unauthorized(caller.error);

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const isSysAdmin = await callerIsSysAdmin(supabase, caller.user.id);
    if (!isSysAdmin) return forbidden();

    const roleId = await roleIdForCode(supabase, input.role);
    if (!roleId) return badRequest('Role does not exist');

    const tenantId = input.isPlatformRole ? input.tenantId ?? await primaryTenantId(supabase) : null;
    if (input.isPlatformRole && !tenantId) return badRequest('tenant_id is required for KC staff roles');
    if (tenantId && !(await ensureTenantExists(supabase, tenantId))) return badRequest('tenant_id does not exist');
    if (input.hoaId && !(await ensureHoaExists(supabase, input.hoaId))) return badRequest('hoa_id does not exist');

    const { user, invited } = await inviteOrUpdateAuthUser(supabase, input, redirectTo);
    if (!user) return serverError('Unable to create or locate Auth user');

    const { error: profileError } = await supabase.from('profiles').upsert({
      id: user.id,
      email: input.email,
      full_name: input.fullName,
      phone: input.phone,
      status: 'active',
    }, { onConflict: 'id' });

    if (profileError) throw profileError;

    if (input.isPlatformRole) {
      const { error } = await supabase.from('user_platform_roles').upsert({
        user_id: user.id,
        tenant_id: tenantId,
        role_id: roleId,
        assigned_by: caller.user.id,
      }, { onConflict: 'user_id,tenant_id,role_id' });
      if (error) throw error;
    } else {
      const { error } = await supabase.from('user_hoa_memberships').upsert({
        user_id: user.id,
        hoa_id: input.hoaId,
        role_id: roleId,
        status: 'active',
        assigned_by: caller.user.id,
      }, { onConflict: 'user_id,hoa_id,role_id' });
      if (error) throw error;
    }

    await writeAuditLog(supabase, caller.user.id, user.id, input, request);

    return jsonResponse({
      success: true,
      user_id: user.id,
      message: invited
        ? 'Invitation email generated and user role assigned.'
        : 'Existing user found; profile and role assignment updated.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected invite failure';
    return serverError(message);
  }
});
