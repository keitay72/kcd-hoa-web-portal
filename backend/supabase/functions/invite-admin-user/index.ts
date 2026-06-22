import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type InviteAction = 'invite' | 'resend' | 'cancel';

type InviteAdminUserRequest = {
  action?: InviteAction;
  invite_id?: string;
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
  isGlobalPlatformRole: boolean;
  isTenantRole: boolean;
  isCommunityRole: boolean;
};

type ParseResult =
  | { ok: true; value: ParsedInvite }
  | { ok: false; error: string };

type CallerResult =
  | { user: { id: string }; error?: never }
  | { error: string; user?: never };

type RoleRow = { id: number; code: string };
type InviteRow = {
  id: string;
  user_id: string | null;
  email: string;
  first_name: string;
  middle_name: string | null;
  last_name: string;
  phone: string | null;
  role_id: number;
  role_code: string;
  tenant_id: string | null;
  hoa_id: string | null;
  status: string;
  resend_count: number;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const globalPlatformRoles = new Set(['platform_owner', 'platform_admin', 'platform_support', 'platform_sales']);
const tenantRoles = new Set(['tenant_owner', 'tenant_admin', 'tenant_manager', 'tenant_csr', 'tenant_dispatch']);
const communityRoles = new Set(['community_admin']);
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

function forbidden(message = 'You do not have permission to manage invitations for this scope') {
  return jsonResponse({ success: false, message }, 403);
}

function invalidInviteRedirect(message: string) {
  return jsonResponse({ success: false, message }, 500);
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

function maskEmail(email: string) {
  const [localPart, domain] = email.split('@');
  if (!domain) return 'invalid-email';
  const visible = localPart.slice(0, 2);
  return `${visible}${'*'.repeat(Math.max(localPart.length - 2, 1))}@${domain}`;
}

function validateInviteRedirect(redirectTo: string | undefined) {
  if (!redirectTo) {
    return 'ADMIN_INVITE_REDIRECT_URL is not configured. Set it to the admin app /accept-invite URL before sending invitations.';
  }

  try {
    const url = new URL(redirectTo);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      return 'ADMIN_INVITE_REDIRECT_URL must start with http:// or https://.';
    }
    if (url.pathname !== '/accept-invite') {
      return 'ADMIN_INVITE_REDIRECT_URL must point to /accept-invite.';
    }
  } catch (_) {
    return 'ADMIN_INVITE_REDIRECT_URL must be a valid absolute URL.';
  }

  return null;
}

function defaultLocalInviteRedirect(supabaseUrl: string | undefined) {
  if (!supabaseUrl) return undefined;

  try {
    const url = new URL(supabaseUrl);
    if (url.hostname === '127.0.0.1' || url.hostname === 'localhost' || url.hostname === 'kong') {
      return 'http://127.0.0.1:8080/accept-invite';
    }
  } catch (_) {
    return undefined;
  }

  return undefined;
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
  if (role === 'platform_owner') return { ok: false, error: 'Platform Owner accounts must be created manually' };
  if (!globalPlatformRoles.has(role) && !tenantRoles.has(role) && !communityRoles.has(role)) return { ok: false, error: 'Role is invalid' };
  if (globalPlatformRoles.has(role) && (tenantId || hoaId)) return { ok: false, error: 'Platform roles must not include tenant_id or hoa_id' };
  if (tenantRoles.has(role) && hoaId) return { ok: false, error: 'Tenant staff roles must not include hoa_id' };
  if (tenantRoles.has(role) && !tenantId) return { ok: false, error: 'Tenant staff roles require tenant_id' };
  if (communityRoles.has(role) && !hoaId) return { ok: false, error: 'Community roles require hoa_id' };

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
      isGlobalPlatformRole: globalPlatformRoles.has(role),
      isTenantRole: tenantRoles.has(role),
      isCommunityRole: communityRoles.has(role),
    },
  };
}

function inputFromInviteRow(row: InviteRow): ParsedInvite {
  const middleName = row.middle_name;
  const role = row.role_code;
  return {
    email: row.email.toLowerCase(),
    firstName: row.first_name,
    middleName,
    lastName: row.last_name,
    fullName: fullName(row.first_name, middleName, row.last_name),
    phone: row.phone ?? '',
    role,
    tenantId: row.tenant_id,
    hoaId: row.hoa_id,
    isGlobalPlatformRole: globalPlatformRoles.has(role),
    isTenantRole: tenantRoles.has(role),
    isCommunityRole: communityRoles.has(role),
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

function authUserAccepted(user: { email_confirmed_at?: string | null; last_sign_in_at?: string | null } | null) {
  return Boolean(user?.email_confirmed_at || user?.last_sign_in_at);
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

async function callerCanManageInvites(supabase: SupabaseClient, userId: string) {
  const roles = await callerGlobalPlatformRoles(supabase, userId);
  return roles.has('platform_owner') || roles.has('platform_admin');
}

async function callerGlobalPlatformRoles(supabase: SupabaseClient, userId: string) {
  const { data: globalRoles, error: globalRoleError } = await supabase
    .from('user_global_roles')
    .select('roles!inner(code)')
    .eq('user_id', userId)
    .in('roles.code', ['platform_owner', 'platform_admin', 'platform_support', 'platform_sales']);

  if (globalRoleError) throw globalRoleError;
  const roles = new Set<string>();
  if (!Array.isArray(globalRoles)) return roles;

  for (const row of globalRoles) {
    const role = row.roles;
    if (Array.isArray(role)) {
      for (const item of role) {
        if (typeof item?.code === 'string') roles.add(item.code);
      }
    } else if (typeof role?.code === 'string') {
      roles.add(role.code);
    }
  }

  return roles;
}

async function assertCallerCanInviteGlobalPlatformRole(
  supabase: SupabaseClient,
  actorUserId: string,
  roleCode: string,
) {
  if (roleCode === 'platform_owner') {
    throw new Error('Platform Owner accounts must be created manually');
  }

  const actorRoles = await callerGlobalPlatformRoles(supabase, actorUserId);
  if (actorRoles.has('platform_owner')) return;

  if (
    actorRoles.has('platform_admin') &&
    (roleCode === 'platform_support' || roleCode === 'platform_sales')
  ) {
    return;
  }

  if (roleCode === 'platform_admin') {
    throw new Error('Only platform owners may invite Platform Admin users');
  }

  throw new Error('Only platform owners or platform admins may assign global platform roles');
}

async function hoaTenantId(supabase: SupabaseClient, hoaId: string) {
  const { data, error } = await supabase
    .from('hoa_communities')
    .select('tenant_id')
    .eq('id', hoaId)
    .maybeSingle();

  if (error) throw error;
  return data?.tenant_id as string | null;
}

async function communityCustomerAccountForHoa(supabase: SupabaseClient, hoaId: string) {
  const { data, error } = await supabase
    .from('customer_accounts')
    .select('id, tenant_id')
    .eq('account_type', 'community')
    .eq('external_account_ref', hoaId)
    .maybeSingle();

  if (error) throw error;
  return data as { id: string; tenant_id: string } | null;
}

async function callerCanManageTenantScopedInvites(
  supabase: SupabaseClient,
  userId: string,
  tenantId: string,
) {
  if (await callerCanManageInvites(supabase, userId)) return true;

  const { data, error } = await supabase
    .from('user_tenant_roles')
    .select('role_id, roles!inner(code)')
    .eq('user_id', userId)
    .eq('tenant_id', tenantId)
    .in('roles.code', ['tenant_owner', 'tenant_admin', 'tenant_manager', 'sys_admin', 'mgmt'])
    .limit(1);

  if (error) throw error;
  return Array.isArray(data) && data.length > 0;
}

async function callerCanManageHoaScopedInvites(
  supabase: SupabaseClient,
  userId: string,
  hoaId: string,
  roleCode: string,
) {
  if (roleCode !== 'community_admin') return false;

  const { data, error } = await supabase
    .from('user_hoa_memberships')
    .select('role_id, roles!inner(code)')
    .eq('user_id', userId)
    .eq('hoa_id', hoaId)
    .eq('status', 'active')
    .in('roles.code', ['hoa_manager'])
    .limit(1);

  if (error) throw error;
  return Array.isArray(data) && data.length > 0;
}

async function resolvedTenantScopeForInvite(
  supabase: SupabaseClient,
  input: ParsedInvite,
  resolvedTenantId: string | null,
) {
  if (input.isGlobalPlatformRole) return null;
  if (input.isTenantRole) return resolvedTenantId;
  if (input.isCommunityRole && input.hoaId) return await hoaTenantId(supabase, input.hoaId);
  if (!input.hoaId) return null;
  return await hoaTenantId(supabase, input.hoaId);
}

async function assertInvitePermissionForParsedInput(
  supabase: SupabaseClient,
  actorUserId: string,
  input: ParsedInvite,
  resolvedTenantId: string | null,
) {
  if (input.isGlobalPlatformRole) {
    await assertCallerCanInviteGlobalPlatformRole(supabase, actorUserId, input.role);
    return;
  }

  if (input.hoaId) {
    const canManageHoaInvite = await callerCanManageHoaScopedInvites(
      supabase,
      actorUserId,
      input.hoaId,
      input.role,
    );
    if (canManageHoaInvite) return;
  }

  const tenantScopeId = await resolvedTenantScopeForInvite(supabase, input, resolvedTenantId);
  if (!tenantScopeId) {
    throw new Error('Unable to resolve tenant scope for this invitation');
  }

  const canManageScopedInvite = await callerCanManageTenantScopedInvites(
    supabase,
    actorUserId,
    tenantScopeId,
  );
  if (!canManageScopedInvite) {
    throw new Error('Only platform admins or tenant owners/admins/managers may manage invitations for this tenant');
  }
}

async function assertInvitePermissionForStoredInvite(
  supabase: SupabaseClient,
  actorUserId: string,
  invite: InviteRow,
) {
  const roleCode = invite.role_code;

  if (globalPlatformRoles.has(roleCode)) {
    await assertCallerCanInviteGlobalPlatformRole(supabase, actorUserId, roleCode);
    return;
  }

  if (invite.hoa_id) {
    const canManageHoaInvite = await callerCanManageHoaScopedInvites(
      supabase,
      actorUserId,
      invite.hoa_id,
      invite.role_code,
    );
    if (canManageHoaInvite) return;
  }

  const tenantScopeId = invite.tenant_id ?? (invite.hoa_id ? await hoaTenantId(supabase, invite.hoa_id) : null);
  if (!tenantScopeId) {
    throw new Error('Unable to resolve tenant scope for this invitation');
  }

  const canManageScopedInvite = await callerCanManageTenantScopedInvites(
    supabase,
    actorUserId,
    tenantScopeId,
  );
  if (!canManageScopedInvite) {
    throw new Error('Only platform admins or tenant owners/admins/managers may manage invitations for this tenant');
  }
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

async function roleForCode(supabase: SupabaseClient, role: string): Promise<RoleRow | null> {
  const { data, error } = await supabase
    .from('roles')
    .select('id, code')
    .eq('code', role)
    .maybeSingle();

  if (error) throw error;
  return data as RoleRow | null;
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

async function sendInviteEmail(
  supabase: SupabaseClient,
  input: ParsedInvite,
  redirectTo: string | undefined,
) {
  const metadata = {
    first_name: input.firstName,
    middle_name: input.middleName,
    last_name: input.lastName,
    full_name: input.fullName,
    phone: input.phone,
    invited_role: input.role,
  };

  const { data, error } = await supabase.auth.admin.inviteUserByEmail(input.email, {
    data: metadata,
    redirectTo,
  });

  if (error) throw error;
  return data.user;
}

async function updateExistingAuthUser(
  supabase: SupabaseClient,
  userId: string,
  input: ParsedInvite,
) {
  const { data, error } = await supabase.auth.admin.updateUserById(userId, {
    email: input.email,
    user_metadata: {
      first_name: input.firstName,
      middle_name: input.middleName,
      last_name: input.lastName,
      full_name: input.fullName,
      phone: input.phone,
      invited_role: input.role,
    },
  });

  if (error) throw error;
  return data.user;
}

async function upsertProfile(
  supabase: SupabaseClient,
  userId: string,
  input: ParsedInvite,
  status: 'active' | 'invite_pending' | 'disabled',
) {
  const { error } = await supabase.from('profiles').upsert({
    id: userId,
    email: input.email,
    full_name: input.fullName,
    phone: input.phone,
    status,
  }, { onConflict: 'id' });

  if (error) throw error;
}

async function assignRole(
  supabase: SupabaseClient,
  actorUserId: string,
  userId: string,
  input: ParsedInvite,
  roleId: number,
  tenantId: string | null,
) {
  if (input.isGlobalPlatformRole) {
    const { error } = await supabase.from('user_global_roles').upsert({
      user_id: userId,
      role_id: roleId,
      assigned_by: actorUserId,
    }, { onConflict: 'user_id,role_id' });
    if (error) throw error;
    return;
  }

  if (input.isTenantRole) {
    const { error } = await supabase.from('user_platform_roles').upsert({
      user_id: userId,
      tenant_id: tenantId,
      role_id: roleId,
      assigned_by: actorUserId,
    }, { onConflict: 'user_id,tenant_id,role_id' });
    if (error) throw error;
    return;
  }

  if (input.isCommunityRole) {
    if (!input.hoaId) throw new Error('Community roles require hoa_id');
    const communityAccount = await communityCustomerAccountForHoa(supabase, input.hoaId);
    if (!communityAccount) {
      throw new Error('Unable to find a community customer account for this HOA');
    }

    const { data: existingMembership, error: existingMembershipError } = await supabase
      .from('customer_memberships')
      .select('id')
      .eq('user_id', userId)
      .eq('customer_account_id', communityAccount.id)
      .is('service_location_id', null)
      .eq('role_id', roleId)
      .maybeSingle();

    if (existingMembershipError) throw existingMembershipError;

    if (existingMembership?.id) {
      const { error } = await supabase
        .from('customer_memberships')
        .update({
          tenant_id: communityAccount.tenant_id,
          status: 'active',
          is_primary_contact: false,
          created_by: actorUserId,
        })
        .eq('id', existingMembership.id);
      if (error) throw error;
      return;
    }

    const { error } = await supabase.from('customer_memberships').insert({
      tenant_id: communityAccount.tenant_id,
      user_id: userId,
      customer_account_id: communityAccount.id,
      service_location_id: null,
      role_id: roleId,
      status: 'active',
      is_primary_contact: false,
      created_by: actorUserId,
    });
    if (error) throw error;
    return;
  }

  const { error } = await supabase.from('user_hoa_memberships').upsert({
    user_id: userId,
    hoa_id: input.hoaId,
    role_id: roleId,
    status: 'active',
    assigned_by: actorUserId,
  }, { onConflict: 'user_id,hoa_id,role_id' });
  if (error) throw error;
}

async function pendingInviteByEmail(supabase: SupabaseClient, email: string) {
  const { data, error } = await supabase
    .from('admin_user_invites')
    .select('*')
    .eq('email', email)
    .eq('status', 'pending')
    .maybeSingle();

  if (error) throw error;
  return data as InviteRow | null;
}

async function inviteById(supabase: SupabaseClient, inviteId: string) {
  const { data, error } = await supabase
    .from('admin_user_invites')
    .select('*')
    .eq('id', inviteId)
    .maybeSingle();

  if (error) throw error;
  return data as InviteRow | null;
}

async function recordInvite(
  supabase: SupabaseClient,
  actorUserId: string,
  userId: string | null,
  input: ParsedInvite,
  roleId: number,
  tenantId: string | null,
  status: 'pending' | 'accepted' | 'failed',
  pendingInvite: InviteRow | null,
  incrementResend: boolean,
  failureReason?: string,
) {
  const failedAt = status === 'failed' ? new Date().toISOString() : null;
  const base = {
    user_id: userId,
    email: input.email,
    first_name: input.firstName,
    middle_name: input.middleName,
    last_name: input.lastName,
    phone: input.phone,
    role_id: roleId,
    role_code: input.role,
    tenant_id: input.isTenantRole ? tenantId : null,
    hoa_id: input.isTenantRole ? null : input.hoaId,
    status,
    invited_by: actorUserId,
    accepted_at: status === 'accepted' ? new Date().toISOString() : null,
    expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    failure_message: failureReason ?? null,
    failure_reason: failureReason ?? null,
    failure_timestamp: failedAt,
  };

  if (pendingInvite) {
    const { data, error } = await supabase
      .from('admin_user_invites')
      .update({
        ...base,
        resent_at: incrementResend ? new Date().toISOString() : pendingInvite.status === 'pending' ? new Date().toISOString() : null,
        resend_count: incrementResend ? pendingInvite.resend_count + 1 : pendingInvite.resend_count,
        cancelled_at: null,
        cancelled_by: null,
      })
      .eq('id', pendingInvite.id)
      .select('id')
      .single();
    if (error) throw error;
    return data.id as string;
  }

  const { data, error } = await supabase
    .from('admin_user_invites')
    .insert(base)
    .select('id')
    .single();

  if (error) throw error;
  return data.id as string;
}

async function writeAuditLog(
  supabase: SupabaseClient,
  actorUserId: string,
  invitedUserId: string | null,
  action: string,
  input: ParsedInvite | null,
  request: Request,
  extra: JsonBody = {},
) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null;
  const userAgent = request.headers.get('user-agent');

  const { error } = await supabase.from('admin_audit_logs').insert({
    actor_user_id: actorUserId,
    tenant_id: input?.tenantId ?? null,
    hoa_id: input?.hoaId ?? null,
    action,
    entity_type: 'admin_user_invite',
    entity_id: invitedUserId ?? extra.invite_id?.toString() ?? 'unknown',
    after_json: {
      email: input?.email,
      full_name: input?.fullName,
      phone: input?.phone,
      role: input?.role,
      tenant_id: input?.tenantId,
      hoa_id: input?.hoaId,
      ...extra,
    } as JsonBody,
    ip,
    user_agent: userAgent,
  });

  if (error) throw error;
}

async function handleInvite(
  supabase: SupabaseClient,
  actorUserId: string,
  payload: InviteAdminUserRequest,
  redirectTo: string | undefined,
  request: Request,
) {
  const parsed = parsePayload(payload);
  if (!parsed.ok) return badRequest(parsed.error);
  const input = parsed.value;
  console.info('invite-admin-user invite requested', {
    email: maskEmail(input.email),
    role: input.role,
    scope: input.isGlobalPlatformRole ? 'platform' : input.isTenantRole ? 'tenant' : 'hoa',
  });

  const role = await roleForCode(supabase, input.role);
  if (!role) return badRequest('Role does not exist');

  const resolvedTenantId = input.isTenantRole ? input.tenantId ?? await primaryTenantId(supabase) ?? null : null;
  if (input.isTenantRole && !resolvedTenantId) return badRequest('tenant_id is required for tenant staff roles');
  if (resolvedTenantId && !(await ensureTenantExists(supabase, resolvedTenantId))) return badRequest('tenant_id does not exist');
  if (input.hoaId && !(await ensureHoaExists(supabase, input.hoaId))) return badRequest('hoa_id does not exist');

  await assertInvitePermissionForParsedInput(supabase, actorUserId, input, resolvedTenantId);

  const pendingInvite = await pendingInviteByEmail(supabase, input.email);
  const existingUser = await findAuthUserByEmail(supabase, input.email);
  let authUser = existingUser;
  let emailSent = false;

  if (!existingUser || !authUserAccepted(existingUser)) {
    try {
      authUser = await sendInviteEmail(supabase, input, redirectTo);
      emailSent = true;
    } catch (error) {
      const failureReason = error instanceof Error ? error.message : 'Invite email generation failed';
      const inviteId = await recordInvite(
        supabase,
        actorUserId,
        existingUser?.id ?? null,
        input,
        role.id,
        resolvedTenantId,
        'failed',
        pendingInvite,
        Boolean(pendingInvite),
        failureReason,
      );

      await writeAuditLog(supabase, actorUserId, existingUser?.id ?? null, 'invite_admin_user_failed', input, request, {
        invite_id: inviteId,
        email_sent: false,
        invite_status: 'failed',
        failure_reason: failureReason,
      });

      console.error('invite-admin-user invite failed', {
        email: maskEmail(input.email),
        inviteId,
        failureReason,
      });

      return jsonResponse({
        success: false,
        user_id: existingUser?.id ?? null,
        invite_id: inviteId,
        message: `Invitation failed: ${failureReason}`,
      }, 202);
    }
  } else {
    authUser = await updateExistingAuthUser(supabase, existingUser.id, input);
  }

  console.info('invite-admin-user auth invite result', {
    email: maskEmail(input.email),
    existingUser: Boolean(existingUser),
    acceptedUser: authUserAccepted(authUser),
    emailSent,
  });

  if (!authUser) return serverError('Unable to create or locate Auth user');

  const accepted = authUserAccepted(authUser);
  await upsertProfile(supabase, authUser.id, input, accepted ? 'active' : 'invite_pending');
  await assignRole(supabase, actorUserId, authUser.id, input, role.id, resolvedTenantId);
  const inviteId = await recordInvite(
    supabase,
    actorUserId,
    authUser.id,
    input,
    role.id,
    resolvedTenantId,
    accepted ? 'accepted' : 'pending',
    pendingInvite,
    Boolean(pendingInvite),
  );

  await writeAuditLog(supabase, actorUserId, authUser.id, 'invite_admin_user', input, request, {
    invite_id: inviteId,
    email_sent: emailSent,
    invite_status: accepted ? 'accepted' : 'pending',
  });

  console.info('invite-admin-user invite completed', {
    email: maskEmail(input.email),
    inviteId,
    emailSent,
    status: accepted ? 'accepted' : 'pending',
  });

  return jsonResponse({
    success: true,
    user_id: authUser.id,
    invite_id: inviteId,
    message: emailSent
      ? 'Invitation email generated and user role assigned.'
      : 'Existing accepted user found; profile and role assignment updated.',
  });
}

async function handleResend(
  supabase: SupabaseClient,
  actorUserId: string,
  inviteId: string | undefined,
  redirectTo: string | undefined,
  request: Request,
) {
  if (!inviteId) return badRequest('invite_id is required');
  console.info('invite-admin-user resend requested', { inviteId });
  const invite = await inviteById(supabase, inviteId);
  if (!invite) return badRequest('Invite not found');
  await assertInvitePermissionForStoredInvite(supabase, actorUserId, invite);
  if (invite.status !== 'pending' && invite.status !== 'expired' && invite.status !== 'failed') {
    return badRequest('Only pending, expired, or failed invites may be resent');
  }

  const input = inputFromInviteRow(invite);
  let authUser;
  try {
    authUser = await sendInviteEmail(supabase, input, redirectTo);
  } catch (error) {
    const failureReason = error instanceof Error ? error.message : 'Invite email resend failed';
    const { error: updateError } = await supabase
      .from('admin_user_invites')
      .update({
        status: 'failed',
        failure_message: failureReason,
        failure_reason: failureReason,
        failure_timestamp: new Date().toISOString(),
        resent_at: new Date().toISOString(),
        resend_count: invite.resend_count + 1,
      })
      .eq('id', invite.id);
    if (updateError) throw updateError;

    await writeAuditLog(supabase, actorUserId, invite.user_id, 'resend_admin_user_invite_failed', input, request, {
      invite_id: invite.id,
      failure_reason: failureReason,
    });

    return jsonResponse({
      success: false,
      user_id: invite.user_id,
      invite_id: invite.id,
      message: `Invitation resend failed: ${failureReason}`,
    }, 202);
  }
  if (!authUser) return serverError('Unable to resend invite email');

  await upsertProfile(supabase, authUser.id, input, 'invite_pending');

  const { error } = await supabase
    .from('admin_user_invites')
    .update({
      user_id: authUser.id,
      status: 'pending',
      resent_at: new Date().toISOString(),
      resend_count: invite.resend_count + 1,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      cancelled_at: null,
      cancelled_by: null,
      failure_message: null,
      failure_reason: null,
      failure_timestamp: null,
    })
    .eq('id', invite.id);

  if (error) throw error;

  await writeAuditLog(supabase, actorUserId, authUser.id, 'resend_admin_user_invite', input, request, {
    invite_id: invite.id,
  });

  console.info('invite-admin-user resend completed', {
    inviteId: invite.id,
    email: maskEmail(input.email),
  });

  return jsonResponse({
    success: true,
    user_id: authUser.id,
    invite_id: invite.id,
    message: 'Invitation email resent.',
  });
}

async function handleCancel(
  supabase: SupabaseClient,
  actorUserId: string,
  inviteId: string | undefined,
  request: Request,
) {
  if (!inviteId) return badRequest('invite_id is required');
  console.info('invite-admin-user cancel requested', { inviteId });
  const invite = await inviteById(supabase, inviteId);
  if (!invite) return badRequest('Invite not found');
  await assertInvitePermissionForStoredInvite(supabase, actorUserId, invite);
  if (invite.status !== 'pending' && invite.status !== 'expired' && invite.status !== 'failed') {
    return badRequest('Only pending, expired, or failed invites may be cancelled');
  }

  const now = new Date().toISOString();
  const { error } = await supabase
    .from('admin_user_invites')
    .update({
      status: 'cancelled',
      cancelled_at: now,
      cancelled_by: actorUserId,
    })
    .eq('id', invite.id);

  if (error) throw error;

  if (invite.user_id) {
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ status: 'disabled' })
      .eq('id', invite.user_id)
      .eq('status', 'invite_pending');
    if (profileError) throw profileError;
  }

  await writeAuditLog(supabase, actorUserId, invite.user_id, 'cancel_admin_user_invite', inputFromInviteRow(invite), request, {
    invite_id: invite.id,
  });

  console.info('invite-admin-user cancel completed', { inviteId: invite.id });

  return jsonResponse({
    success: true,
    user_id: invite.user_id,
    invite_id: invite.id,
    message: 'Invitation cancelled.',
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return jsonResponse({ ok: true });
  if (request.method !== 'POST') return jsonResponse({ success: false, message: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const redirectTo = Deno.env.get('ADMIN_INVITE_REDIRECT_URL') || defaultLocalInviteRedirect(supabaseUrl);

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return serverError('Server configuration is missing');
  }

  let payload: InviteAdminUserRequest;
  try {
    payload = (await request.json()) as InviteAdminUserRequest;
  } catch (_) {
    return badRequest('Invalid JSON body');
  }

  const caller = await requireCallerUser(request, supabaseUrl, anonKey);
  if ('error' in caller) return unauthorized(caller.error);

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const action = payload.action ?? 'invite';
    if (action === 'invite' || action === 'resend') {
      const redirectError = validateInviteRedirect(redirectTo);
      if (redirectError) {
        console.error('invite-admin-user redirect misconfigured', { redirectError });
        return invalidInviteRedirect(redirectError);
      }
    }

    if (action === 'resend') {
      return await handleResend(supabase, caller.user.id, payload.invite_id, redirectTo, request);
    }
    if (action === 'cancel') {
      return await handleCancel(supabase, caller.user.id, payload.invite_id, request);
    }
    if (action === 'invite') {
      return await handleInvite(supabase, caller.user.id, payload, redirectTo, request);
    }

    return badRequest('Unsupported invite action');
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    if (
      message.includes('Only platform owners or platform admins may assign global platform roles') ||
      message.includes('Only platform owners or platform admins may manage global platform invites') ||
      message.includes('Only platform admins or tenant owners/admins/managers may manage invitations for this tenant')
    ) {
      return forbidden(message);
    }
    console.error('invite-admin-user failed', { message });
    return serverError(message || 'Unexpected invite failure');
  }
});
