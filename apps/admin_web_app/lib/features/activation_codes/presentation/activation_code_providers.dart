import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/activation_code_repository.dart';
import '../domain/activation_code.dart';
import '../domain/activation_code_address_option.dart';
import '../domain/activation_code_event.dart';
import '../domain/activation_code_inputs.dart';
import '../domain/generated_activation_code.dart';

final activationCodeRepositoryProvider =
    Provider<ActivationCodeRepository>((ref) {
  return SupabaseActivationCodeRepository(ref.watch(supabaseClientProvider));
});

final activationCodeListProvider = FutureProvider.autoDispose
    .family<List<ActivationCode>, String?>((ref, status) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items =
      await ref.watch(activationCodeRepositoryProvider).list(status: status);
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final activationCodeDetailProvider =
    FutureProvider.autoDispose.family<ActivationCode, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(activationCodeRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.hoaId)) {
    throw StateError('Activation code is outside the active view.');
  }
  return item;
});

final activationCodeEventsProvider = FutureProvider.autoDispose
    .family<List<ActivationCodeEvent>, String>((ref, id) {
  return ref.watch(activationCodeRepositoryProvider).eventsForCode(id);
});

final activationCodeAddressOptionsProvider =
    FutureProvider.autoDispose<List<ActivationCodeAddressOption>>((ref) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items =
      await ref.watch(activationCodeRepositoryProvider).addressOptions();
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final activationCodeCommandProvider = AsyncNotifierProvider.autoDispose<
    ActivationCodeCommandController, GeneratedActivationCode?>(
  ActivationCodeCommandController.new,
);

class ActivationCodeCommandController
    extends AutoDisposeAsyncNotifier<GeneratedActivationCode?> {
  @override
  FutureOr<GeneratedActivationCode?> build() => null;

  Future<GeneratedActivationCode?> generateCode(
    GenerateActivationCodeInput input,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(activationCodeRepositoryProvider).generate(input);
    });

    if (result.hasError) {
      state = AsyncError<GeneratedActivationCode?>(
        result.error!,
        result.stackTrace!,
      );
      return null;
    }

    state = AsyncData(result.value);
    _invalidateCodeViews(result.value?.activationCode.id);
    return result.value;
  }

  Future<GeneratedActivationCode?> resetCode(
      ResetActivationCodeInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(activationCodeRepositoryProvider).reset(input);
    });

    if (result.hasError) {
      state = AsyncError<GeneratedActivationCode?>(
        result.error!,
        result.stackTrace!,
      );
      return null;
    }

    state = AsyncData(result.value);
    _invalidateCodeViews(input.activationCodeId);
    return result.value;
  }

  Future<ActivationCode?> revokeCode(RevokeActivationCodeInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(activationCodeRepositoryProvider).revoke(input);
    });

    if (result.hasError) {
      state = AsyncError<GeneratedActivationCode?>(
        result.error!,
        result.stackTrace!,
      );
      return null;
    }

    state = const AsyncData(null);
    _invalidateCodeViews(input.activationCodeId);
    return result.value;
  }

  void clearGeneratedCode() {
    state = const AsyncData(null);
  }

  void _invalidateCodeViews(String? activationCodeId) {
    ref.invalidate(activationCodeListProvider(null));
    for (final status in ActivationCodeStatus.values) {
      ref.invalidate(activationCodeListProvider(status.name));
    }
    if (activationCodeId != null) {
      ref.invalidate(activationCodeDetailProvider(activationCodeId));
      ref.invalidate(activationCodeEventsProvider(activationCodeId));
    }
  }
}
