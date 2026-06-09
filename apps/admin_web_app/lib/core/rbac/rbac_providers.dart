import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_provider.dart';
import 'admin_access.dart';
import 'permission_service.dart';
import 'rbac_service.dart';
import 'role_service.dart';

final roleServiceProvider = Provider<RoleService>((ref) {
  return SupabaseRoleService(ref.watch(supabaseClientProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return SupabasePermissionService(ref.watch(supabaseClientProvider));
});

final rbacServiceProvider = Provider<RbacService>((ref) {
  return DefaultRbacService(
    roleService: ref.watch(roleServiceProvider),
    permissionService: ref.watch(permissionServiceProvider),
  );
});

final adminAccessProvider = FutureProvider.autoDispose<AdminAccess>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const AdminAccess(
      userId: '',
      platformRoles: [],
      hoaRoles: [],
      permissions: {},
    );
  }

  return ref.watch(rbacServiceProvider).accessForUser(user.id);
});

final currentAdminRoleSummaryProvider = FutureProvider.autoDispose<String>((ref) async {
  final access = await ref.watch(adminAccessProvider.future);
  return access.roleSummary;
});
