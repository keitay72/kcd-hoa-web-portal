import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_user.dart';
import '../domain/user_management_inputs.dart';
import 'admin_user_dto.dart';

abstract interface class UserRepository {
  Future<List<AdminUser>> list({String? search, String? status});
  Future<AdminUser> getById(String id);
  Future<void> invite(InviteAdminUserInput input);
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

  static const _profileSelect = 'id, email, full_name, phone, status, created_at, updated_at';
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
    var query = _client.from('profiles').select(_profileSelect);
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final profileRows = await query.order('created_at', ascending: false);
    final users = <AdminUser>[];
    final needle = search?.trim().toLowerCase();

    for (final row in profileRows) {
      final dto = AdminUserDto.fromJson(row);
      if (needle != null && needle.isNotEmpty) {
        final haystack = '${dto.email} ${dto.fullName ?? ''} ${dto.phone ?? ''}'.toLowerCase();
        if (!haystack.contains(needle)) continue;
      }
      users.add(await _hydrate(dto));
    }

    return users;
  }

  @override
  Future<AdminUser> getById(String id) async {
    final row = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('id', id)
        .single();

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<void> invite(InviteAdminUserInput input) async {
    try {
      final response = await _client.functions.invoke(
        'invite-admin-user',
        body: input.toJson(),
      );

      if (response.status >= 400) {
        throw InviteAdminUserUnavailableException(
          'invite-admin-user returned HTTP ${response.status}. Deploy or fix the Edge Function before live invitations work.',
        );
      }
    } on Exception catch (error) {
      throw InviteAdminUserUnavailableException(
        'invite-admin-user is unavailable: $error. Deploy the Edge Function before live invitations work.',
      );
    }
  }

  @override
  Future<AdminUser> update({
    required String id,
    required UpdateAdminUserInput input,
  }) async {
    final row = await _client
        .from('profiles')
        .update(input.toJson())
        .eq('id', id)
        .select(_profileSelect)
        .single();

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<AdminUser> deactivate(String id) async {
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

    return _hydrate(AdminUserDto.fromJson(row));
  }

  @override
  Future<void> assignPlatformRole(AssignPlatformRoleInput input) async {
    await _client.from('user_platform_roles').upsert({
      'user_id': input.userId,
      'tenant_id': input.tenantId,
      'role_id': input.roleId,
      'assigned_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> assignHoaRole(AssignHoaRoleInput input) async {
    await _client.from('user_hoa_memberships').upsert({
      'user_id': input.userId,
      'hoa_id': input.hoaId,
      'role_id': input.roleId,
      'status': 'active',
      'assigned_by': _client.auth.currentUser?.id,
    });
  }

  @override
  Future<void> removePlatformRole(UserPlatformRoleAssignment assignment) async {
    await _client
        .from('user_platform_roles')
        .delete()
        .eq('user_id', assignment.userId)
        .eq('tenant_id', assignment.tenantId)
        .eq('role_id', assignment.roleId);
  }

  @override
  Future<void> removeHoaRole(UserHoaRoleAssignment assignment) async {
    await _client
        .from('user_hoa_memberships')
        .update({'status': 'inactive'})
        .eq('user_id', assignment.userId)
        .eq('hoa_id', assignment.hoaId)
        .eq('role_id', assignment.roleId);
  }

  Future<AdminUser> _hydrate(AdminUserDto dto) async {
    final platformRoles = await _platformRoles(dto.id);
    final hoaRoles = await _hoaRoles(dto.id);
    return dto.toDomain(platformRoles: platformRoles, hoaRoles: hoaRoles);
  }

  Future<List<UserPlatformRoleAssignment>> _platformRoles(String userId) async {
    final rows = await _client
        .from('user_platform_roles')
        .select(_platformRoleSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => UserPlatformRoleAssignmentDto.fromJson(row).toDomain())
        .toList();
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
