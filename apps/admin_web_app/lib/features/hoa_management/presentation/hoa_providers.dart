import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/hoa_repository.dart';
import '../domain/hoa_community.dart';
import '../domain/hoa_community_input.dart';

final hoaRepositoryProvider = Provider<HoaRepository>((ref) {
  return SupabaseHoaRepository(ref.watch(supabaseClientProvider));
});

final hoaListProvider =
    FutureProvider.autoDispose<List<HoaCommunity>>((ref) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(hoaRepositoryProvider).list();
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.id)).toList();
});

final hoaDetailProvider =
    FutureProvider.autoDispose.family<HoaCommunity, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(hoaRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.id)) {
    throw StateError('HOA is outside the active view.');
  }
  return item;
});

final hoaCodePreviewProvider =
    FutureProvider.autoDispose.family<String, HoaCodePreviewRequest>(
  (ref, request) {
    if (request.name.trim().isEmpty) {
      return Future.value('');
    }

    return ref.watch(hoaRepositoryProvider).availableCodeForName(
          name: request.name,
          excludingHoaId: request.excludingHoaId,
        );
  },
);

final hoaFormControllerProvider =
    AsyncNotifierProvider.autoDispose<HoaFormController, void>(
  HoaFormController.new,
);

class HoaCodePreviewRequest {
  const HoaCodePreviewRequest({
    required this.name,
    this.excludingHoaId,
  });

  final String name;
  final String? excludingHoaId;

  @override
  bool operator ==(Object other) {
    return other is HoaCodePreviewRequest &&
        other.name == name &&
        other.excludingHoaId == excludingHoaId;
  }

  @override
  int get hashCode => Object.hash(name, excludingHoaId);
}

class HoaFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<HoaCommunity?> create(HoaCommunityInput input,
      {String? tenantId}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(hoaRepositoryProvider).create(input, tenantId: tenantId);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    ref.invalidate(activeHoaIdsProvider);
    ref.invalidate(hoaListProvider);
    return result.value;
  }

  Future<HoaCommunity?> updateHoa({
    required String id,
    required HoaCommunityInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(hoaRepositoryProvider).update(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    ref.invalidate(hoaListProvider);
    ref.invalidate(hoaDetailProvider(id));
    return result.value;
  }
}
