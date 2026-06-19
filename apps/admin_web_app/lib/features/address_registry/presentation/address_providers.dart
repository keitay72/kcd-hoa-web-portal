import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/address_repository.dart';
import '../domain/address_import_result.dart';
import '../domain/hoa_address.dart';
import '../domain/hoa_address_input.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return SupabaseAddressRepository(ref.watch(supabaseClientProvider));
});

final addressListProvider = FutureProvider.autoDispose
    .family<List<HoaAddress>, String?>((ref, hoaId) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(addressRepositoryProvider).list(hoaId: hoaId);
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final addressDetailProvider =
    FutureProvider.autoDispose.family<HoaAddress, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(addressRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.hoaId)) {
    throw StateError('Address is outside the active view.');
  }
  return item;
});

final addressFormControllerProvider =
    AsyncNotifierProvider.autoDispose<AddressFormController, void>(
  AddressFormController.new,
);

final addressImportControllerProvider = AsyncNotifierProvider.autoDispose<
    AddressImportController, AddressImportResult?>(
  AddressImportController.new,
);

class AddressFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<HoaAddress?> create(HoaAddressInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(addressRepositoryProvider).create(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateLists(input.hoaId);
    return result.value;
  }

  Future<HoaAddress?> updateAddress({
    required String id,
    required HoaAddressInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(addressRepositoryProvider).update(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    ref.invalidate(addressDetailProvider(id));
    _invalidateLists(input.hoaId);
    return result.value;
  }

  void _invalidateLists(String hoaId) {
    ref.invalidate(addressListProvider(null));
    ref.invalidate(addressListProvider(hoaId));
  }
}

class AddressImportController
    extends AutoDisposeAsyncNotifier<AddressImportResult?> {
  @override
  FutureOr<AddressImportResult?> build() => null;

  Future<AddressImportResult?> importRows(List<HoaAddressInput> rows) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(addressRepositoryProvider).importCsvRows(rows);
    });

    if (result.hasError) {
      state = AsyncError<AddressImportResult?>(
        result.error!,
        result.stackTrace!,
      );
      return null;
    }

    final value = result.value;
    state = AsyncData(value);
    ref.invalidate(addressListProvider(null));
    for (final row in rows) {
      ref.invalidate(addressListProvider(row.hoaId));
    }
    return value;
  }
}
