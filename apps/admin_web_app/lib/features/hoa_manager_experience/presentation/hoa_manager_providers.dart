import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/admin_context.dart';
import '../../../core/rbac/rbac_providers.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/hoa_manager_repository.dart';
import '../domain/hoa_manager_summary.dart';
import '../domain/hoa_resident.dart';

final hoaManagerRepositoryProvider = Provider<HoaManagerRepository>((ref) {
  return SupabaseHoaManagerRepository(ref.watch(supabaseClientProvider));
});

final hoaManagerHoaRolesProvider =
    FutureProvider.autoDispose<List<AdminRoleAssignment>>((ref) async {
  final access = await ref.watch(adminAccessProvider.future);
  final roles = access.hoaRoles
      .where((role) =>
          role.code == 'hoa_manager' ||
          role.code == 'hoa_board' ||
          role.code == 'hoa_resident')
      .where((role) => role.hoaId != null)
      .toList();

  roles
      .sort((a, b) => (a.hoaName ?? a.hoaId!).compareTo(b.hoaName ?? b.hoaId!));
  return roles;
});

final activeHoaScopeProvider =
    FutureProvider.autoDispose<AdminRoleAssignment?>((ref) async {
  final activeContext = await ref.watch(activeAdminContextProvider.future);
  final roles = await ref.watch(hoaManagerHoaRolesProvider.future);
  if (roles.isEmpty) return null;

  final selectedHoaId =
      activeContext?.isHoa == true ? activeContext?.scopeId : null;
  if (selectedHoaId == null) return roles.first;

  return roles.firstWhere(
    (role) => role.hoaId == selectedHoaId,
    orElse: () => roles.first,
  );
});

final hoaManagerSummaryProvider =
    FutureProvider.autoDispose<HoaManagerSummary>((ref) async {
  final repository = ref.watch(hoaManagerRepositoryProvider);
  final scope = await ref.watch(activeHoaScopeProvider.future);
  if (scope?.hoaId == null) {
    throw StateError('No HOA scope is assigned to this account.');
  }

  return repository.summary(scope!.hoaId!);
});

final hoaResidentListProvider =
    FutureProvider.autoDispose<List<HoaResident>>((ref) async {
  final repository = ref.watch(hoaManagerRepositoryProvider);
  final scope = await ref.watch(activeHoaScopeProvider.future);
  if (scope?.hoaId == null) return const [];

  return repository.residents(scope!.hoaId!);
});
