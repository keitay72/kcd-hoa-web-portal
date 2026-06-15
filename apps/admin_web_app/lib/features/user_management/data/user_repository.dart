import 'package:supabase_flutter/supabase_flutter.dart';

import '../../audit_logs/data/admin_audit_logger.dart';
import '../domain/admin_user.dart';
import '../domain/user_management_inputs.dart';
import 'admin_user_dto.dart';

abstract interface class UserRepository {
  Future<List<AdminUser>> list({String? search, String? status});
  Future<AdminUser> getById(String id);
  Future<void> invite(InviteAdminUserInput input);
  Future<void> resendInvite(InviteLifecycleActionInput input);
  Future<void> cancelInvite(InviteLifecycleActionInput input);
  Future<AdminUser> update({required String id, required UpdateAdminUserInput input});
  Future<AdminUser> deactivate(String id);
  Future<void> assignPlatformRole(AssignPlatformRoleInput input);
  Future<void> assignHoaRole(AssignHoaRoleInput input);
  Future<void> removePlatformRole(UserPlatformRoleAssignment assignment);
  Future<void> removeHoaRole(UserHoaRoleAssignment assignment);
}

class InviteAdminUserUnavailableException implements Exception {
  const InviteAdminUserUnavailableException([this.message]);

  final String? message;

  @override
  String toString() {
    return message ??
        'The invite-admin-user Edge Function must be deployed before live invitations work.';
  }
}

class SupabaseUserRepository implements UserRepository {
  const SupabaseUserRepository(this._client);

  final SupabaseClient _client;

  AdminAuditLogger get _audit => AdminAuditLogger(_client);

  static const _profileSelect = 'id, email, full_name, phone, status, created_at, updated_at';
  static const _inviteSelect = '''
    id,
    user_id,
    email,
    role_code,
    status,
    invited_at,
    accepted_at,
    expires_at,
    resent_at,
    resend_count,
    cancelled_at,
    failure_message,
    failure_reason,
    failure_timestamp
  ''';
  static const _platformRoleSelect = '''
    user_id,
    tenant_id,
    role_id,
    created_at,
    roles(code, name),
    platform_tenants(name)
  ''';
  static const _hoaRoleSelect = '''
    user_id,
    hoa_id,
    role_id,
    status,
    created_at,
    roles(code, name),
    hoa_communities(name)
  ''';

  @override
  Future<List<AdminUser>> list({String? search, String? status}) async {
    await _syncInviteAcceptances();

    final isInviteStatus = status != null && status.startsWith('invite_');
    var query = _client.from('profiles').select(_profileSelect);
    if (status != null && status.isNotEmpty && !isInviteStatus) {
      query = query.eq('status', status);
    }

    final profileRows = await query.order('created_at', ascending: false);
    final users = <AdminUser>[];
    final needle = search?.trim().toLowerCase();

    for (final row in profileRows) {
      final dto = AdminUserDto.fromJson(row);
      final user = await _hydrate(dto);
      if (_matchesUserFilter(user, needle) && _matchesStatusFilter(user, status)) {
        users.add(user);
      }
    }

    if (_shouldIncludeInviteOnlyUsers(status)) {
      final inviteOnlyUsers = await _inviteOnlyUsersForStatus(status);
      for (final user in inviteOnlyUsers) {
        if (_matchesUserFilter(user, needle)) users.add(user);
      }
    }

    return users;
  }

  @override
  Future<AdminUser> getById(String id) async {
    await _syncInviteAcceptances();

    if (id.startsWith('invite:')) {
      final inviteId = id.substring('invite:'.length);
      final invite = await _inviteById(inviteId);
      if (invite == null) throw StateError('Invite not found');
      return _inviteOnlyUser(invite);
    }

    final row = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('id', id)
        .single();

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<void> invite(InviteAdminUserInput input) async {
    await _invokeInviteFunction(input.toJson());
  }

  @override
  Future<void> resendInvite(InviteLifecycleActionInput input) async {
    await _invokeInviteFunction(input.toJson());
  }

  @override
  Future<void> cancelInvite(InviteLifecycleActionInput input) async {
    await _invokeInviteFunction(input.toJson());
  }

  @override
  Future<AdminUser> update({
    required String id,
    required UpdateAdminUserInput input,
  }) async {
    final before = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('id', id)
        .maybeSingle();
    final payload = input.toJson();
    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', id)
        .select(_profileSelect)
        .single();

    await _audit.log(
      action: 'user.profile_updated',
      entityType: 'profile',
      entityId: id,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: Map<String, dynamic>.from(row),
    );

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<AdminUser> deactivate(String id) async {
    final before = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('id', id)
        .maybeSingle();
    final row = await _client
        .from('profiles')
        .update({'status': 'disabled'})
        .eq('id', id)
        .select(_profileSelect)
        .single();

    await _client
        .from('user_hoa_memberships')
        .update({'status': 'inactive'})
        .eq('user_id', id)
        .eq('status', 'active');

    await _audit.log(
      action: 'user.deactivated',
      entityType: 'profile',
      entityId: id,
      beforeJson: before == null ? null : Map<String, dynamic>.from(before),
      afterJson: Map<String, dynamic>.from(row),
    );

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<void> assignPlatformRole(AssignPlatformRoleInput input) async {
    final payload = <String, dynamic>{
      'user_id': input.userId,
      'tenant_id': input.tenantId,
      'role_id': input.roleId,
      'assigned_by': _client.auth.currentUser?.id,
    };
    await _client.from('user_platform_roles').upsert(payload);
    await _audit.log(
      action: 'role.tenant_assigned',
      entityType: 'user_platform_role',
      entityId: '${input.userId}:${input.tenantId}:${input.roleId}',
      tenantId: input.tenantId,
      afterJson: payload,
    );
  }

  @override
  Future<void> assignHoaRole(AssignHoaRoleInput input) async {
    final payload = <String, dynamic>{
      'user_id': input.userId,
      'hoa_id': input.hoaId,
      'role_id': input.roleId,
      'status': 'active',
      'assigned_by': _client.auth.currentUser?.id,
    };
    await _client.from('user_hoa_memberships').upsert(payload);
    await _audit.log(
      action: 'role.hoa_assigned',
      entityType: 'user_hoa_membership',
      entityId: '${input.userId}:${input.hoaId}:${input.roleId}',
      hoaId: input.hoaId,
      afterJson: payload,
    );
  }

  @override
  Future<void> removePlatformRole(UserPlatformRoleAssignment assignment) async {
    final before = <String, dynamic>{
      'user_id': assignment.userId,
      'tenant_id': assignment.tenantId,
      'role_id': assignment.roleId,
      'role_code': assignment.roleCode,
      'role_name': assignment.roleName,
    };
    await _client
        .from('user_platform_roles')
        .delete()
        .eq('user_id', assignment.userId)
        .eq('tenant_id', assignment.tenantId)
        .eq('role_id', assignment.roleId);
    await _audit.log(
      action: 'role.tenant_removed',
      entityType: 'user_platform_role',
      entityId: '${assignment.userId}:${assignment.tenantId}:${assignment.roleId}',
      tenantId: assignment.tenantId,
      beforeJson: before,
    );
  }

  @override
  Future<void> removeHoaRole(UserHoaRoleAssignment assignment) async {
    final before = <String, dynamic>{
      'user_id': assignment.userId,
      'hoa_id': assignment.hoaId,
      'role_id': assignment.roleId,
      'role_code': assignment.roleCode,
      'role_name': assignment.roleName,
    };
    await _client
        .from('user_hoa_memberships')
        .update({'status': 'inactive'})
        .eq('user_id', assignment.userId)
        .eq('hoa_id', assignment.hoaId)
        .eq('role_id', assignment.roleId);
    await _audit.log(
      action: 'role.hoa_removed',
      entityType: 'user_hoa_membership',
      entityId: '${assignment.userId}:${assignment.hoaId}:${assignment.roleId}',
      hoaId: assignment.hoaId,
      beforeJson: before,
      afterJson: {'status': 'inactive'},
    );
  }

  bool _matchesUserFilter(AdminUser user, String? needle) {
    if (needle == null || needle.isEmpty) return true;
    final invite = user.latestInvite;
    final haystack = ('${user.email} '
            '${user.fullName ?? ''} '
            '${user.phone ?? ''} '
            '${user.roleSummary} '
            '${user.statusLabel} '
            '${invite?.failureReason ?? ''} '
            '${invite?.failureMessage ?? ''}')
        .toLowerCase();
    return haystack.contains(needle);
  }

  bool _matchesStatusFilter(AdminUser user, String? status) {
    if (status == null || status.isEmpty) return true;

    final inviteStatus = user.latestInvite?.status;
    return switch (status) {
      'invite_pending' => user.status == 'invite_pending' || inviteStatus == 'pending',
      'invite_expired' => user.status == 'invite_expired' || inviteStatus == 'expired',
      'invite_failed' => user.status == 'invite_failed' || inviteStatus == 'failed',
      'invite_cancelled' => inviteStatus == 'cancelled',
      _ => user.status == status,
    };
  }

  bool _shouldIncludeInviteOnlyUsers(String? status) {
    return status == null ||
        status == 'invite_failed' ||
        status == 'invite_cancelled' ||
        status == 'invite_expired';
  }

  Future<List<AdminUser>> _inviteOnlyUsersForStatus(String? status) async {
    final inviteStatus = switch (status) {
      'invite_failed' => 'failed',
      'invite_cancelled' => 'cancelled',
      'invite_expired' => 'expired',
      _ => null,
    };

    var query = _client
        .from('admin_user_invites')
        .select(_inviteSelect)
        .filter('user_id', 'is', null);

    if (inviteStatus != null) query = query.eq('status', inviteStatus);

    final rows = await query.order('created_at', ascending: false);

    return rows
        .map((row) => _inviteOnlyUser(AdminUserInviteDto.fromJson(row).toDomain()))
        .toList();
  }

  AdminUser _inviteOnlyUser(AdminUserInvite invite) {
    return AdminUser(
      id: 'invite:${invite.id}',
      email: invite.email,
      fullName: null,
      phone: null,
      status: 'invite_${invite.status}',
      createdAt: invite.invitedAt,
      updatedAt: invite.failureTimestamp ?? invite.invitedAt,
      platformRoles: const [],
      hoaRoles: const [],
      latestInvite: invite,
    );
  }

  Future<AdminUserInvite?> _inviteById(String inviteId) async {
    final row = await _client
        .from('admin_user_invites')
        .select(_inviteSelect)
        .eq('id', inviteId)
        .maybeSingle();

    if (row == null) return null;
    return AdminUserInviteDto.fromJson(row).toDomain();
  }

  Future<void> _invokeInviteFunction(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'invite-admin-user',
        body: body,
      );

      if (response.status >= 400) {
        final message = _messageFromResponse(response.data) ??
            'invite-admin-user returned HTTP ${response.status}. Deploy or fix the Edge Function before live invitations work.';
        throw InviteAdminUserUnavailableException(message);
      }
    } on InviteAdminUserUnavailableException {
      rethrow;
    } on Exception catch (error) {
      throw InviteAdminUserUnavailableException(
        'invite-admin-user is unavailable: $error. Deploy the Edge Function before live invitations work.',
      );
    }
  }

  String? _messageFromResponse(Object? data) {
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is Map && data['error'] != null) return data['error'].toString();
    return null;
  }

  Future<void> _syncInviteAcceptances() async {
    await _client.rpc('sync_admin_invite_acceptances');
  }

  Future<AdminUser> _hydrate(AdminUserDto dto) async {
    final platformRoles = await _platformRoles(dto.id);
    final hoaRoles = await _hoaRoles(dto.id);
    final invite = await _latestInvite(dto.id);
    return dto.toDomain(
      platformRoles: platformRoles,
      hoaRoles: hoaRoles,
      latestInvite: invite,
    );
  }

  Future<AdminUserInvite?> _latestInvite(String userId) async {
    final rows = await _client
        .from('admin_user_invites')
        .select(_inviteSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    return AdminUserInviteDto.fromJson(rows.first).toDomain();
  }

  Future<List<UserPlatformRoleAssignment>> _platformRoles(String userId) async {
    final rows = await _client
        .from('user_tenant_roles')
        .select('user_id, tenant_id, role_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final roles = await _roleDetailsById(
      rows.map((row) => row['role_id'] as int),
    );
    final tenants = await _tenantNamesById(
      rows.map((row) => row['tenant_id'] as String),
    );

    return rows.map((row) {
      final roleId = row['role_id'] as int;
      final tenantId = row['tenant_id'] as String;
      final role = roles[roleId];
      return UserPlatformRoleAssignment(
        userId: row['user_id'] as String,
        tenantId: tenantId,
        roleId: roleId,
        roleCode: role?.code ?? 'unknown',
        roleName: role?.name ?? 'Unknown role',
        tenantName: tenants[tenantId] ?? 'Tenant',
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<Map<int, _RoleDetails>> _roleDetailsById(Iterable<int> roleIds) async {
    final ids = roleIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('roles')
        .select('id, code, name')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as int: _RoleDetails(
          code: row['code'] as String? ?? 'unknown',
          name: row['name'] as String? ?? row['code'] as String? ?? 'Unknown role',
        ),
    };
  }

  Future<Map<String, String>> _tenantNamesById(Iterable<String> tenantIds) async {
    final ids = tenantIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('platform_tenants')
        .select('id, name')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: row['name'] as String? ?? 'Tenant',
    };
  }

  Future<List<UserHoaRoleAssignment>> _hoaRoles(String userId) async {
    final rows = await _client
        .from('user_hoa_memberships')
        .select(_hoaRoleSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => UserHoaRoleAssignmentDto.fromJson(row).toDomain())
        .toList();
  }
}

class _RoleDetails {
  const _RoleDetails({required this.code, required this.name});

  final String code;
  final String name;
}
