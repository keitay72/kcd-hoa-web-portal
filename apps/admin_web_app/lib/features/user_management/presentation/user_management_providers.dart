import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/role_repository.dart';
import '../data/user_repository.dart';
import '../domain/admin_user.dart';
import '../domain/role_catalog.dart';
import '../domain/user_management_inputs.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SupabaseUserRepository(ref.watch(supabaseClientProvider));
});

final roleRepositoryProvider = Provider<RoleRepository>((ref) {
  return SupabaseRoleRepository(ref.watch(supabaseClientProvider));
});

final userListProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, UserListFilter>((ref, filter) {
  return ref.watch(userRepositoryProvider).list(
        search: filter.search,
        status: filter.status,
      );
});

final userDetailProvider = FutureProvider.autoDispose.family<AdminUser, String>((ref, id) {
  return ref.watch(userRepositoryProvider).getById(id);
});

final roleCatalogProvider = FutureProvider.autoDispose<List<RoleCatalogEntry>>((ref) {
  return ref.watch(roleRepositoryProvider).roles();
});

final permissionCatalogProvider = FutureProvider.autoDispose<List<PermissionCatalogEntry>>((ref) {
  return ref.watch(roleRepositoryProvider).permissions();
});

final platformTenantOptionsProvider = FutureProvider.autoDispose<List<PlatformTenantOption>>((ref) {
  return ref.watch(roleRepositoryProvider).platformTenants();
});

final hoaScopeOptionsProvider = FutureProvider.autoDispose<List<HoaScopeOption>>((ref) {
  return ref.watch(roleRepositoryProvider).hoaCommunities();
});

final userCommandProvider = AsyncNotifierProvider.autoDispose<UserCommandController, void>(
  UserCommandController.new,
);

class UserListFilter {
  const UserListFilter({this.search, this.status});

  final String? search;
  final String? status;

  @override
  bool operator ==(Object other) {
    return other is UserListFilter && other.search == search && other.status == status;
  }

  @override
  int get hashCode => Object.hash(search, status);
}

class UserCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> inviteUser(InviteAdminUserInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).invite(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    _invalidateUsers();
    return true;
  }

  Future<AdminUser?> updateUser({
    required String id,
    required UpdateAdminUserInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).update(id: id, input: input);
    });

    return _finishUserCommand(result, id);
  }

  Future<AdminUser?> deactivateUser(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).deactivate(id);
    });

    return _finishUserCommand(result, id);
  }

  Future<bool> assignPlatformRole(AssignPlatformRoleInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).assignPlatformRole(input);
    });

    return _finishVoidCommand(result, input.userId);
  }

  Future<bool> assignHoaRole(AssignHoaRoleInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).assignHoaRole(input);
    });

    return _finishVoidCommand(result, input.userId);
  }

  Future<bool> removePlatformRole(UserPlatformRoleAssignment assignment) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).removePlatformRole(assignment);
    });

    return _finishVoidCommand(result, assignment.userId);
  }

  Future<bool> removeHoaRole(UserHoaRoleAssignment assignment) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).removeHoaRole(assignment);
    });

    return _finishVoidCommand(result, assignment.userId);
  }

  AdminUser? _finishUserCommand(AsyncValue<AdminUser> result, String userId) {
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateUsers(userId);
    return result.value;
  }

  bool _finishVoidCommand(AsyncValue<void> result, String userId) {
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    _invalidateUsers(userId);
    return true;
  }

  void _invalidateUsers([String? userId]) {
    ref.invalidate(userListProvider);
    if (userId != null) ref.invalidate(userDetailProvider(userId));
  }
}
