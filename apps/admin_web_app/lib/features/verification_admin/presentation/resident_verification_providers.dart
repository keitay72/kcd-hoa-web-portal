import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/resident_verification_repository.dart';
import '../domain/resident_verification.dart';

final residentVerificationRepositoryProvider =
    Provider<ResidentVerificationRepository>((ref) {
  return SupabaseResidentVerificationRepository(
    ref.watch(supabaseClientProvider),
  );
});

final residentVerificationListProvider = FutureProvider.autoDispose
    .family<List<ResidentVerification>, ResidentVerificationListFilter>(
  (ref, filter) {
    return ref.watch(residentVerificationRepositoryProvider).list(filter);
  },
);

final residentVerificationDetailProvider = FutureProvider.autoDispose
    .family<ResidentVerification, String>((ref, id) {
  return ref.watch(residentVerificationRepositoryProvider).getById(id);
});

final residentVerificationHistoryProvider = FutureProvider.autoDispose
    .family<List<ResidentAddressMembershipHistory>, String>((ref, userId) {
  return ref.watch(residentVerificationRepositoryProvider).historyForUser(userId);
});

final residentVerificationCommandProvider =
    AsyncNotifierProvider.autoDispose<ResidentVerificationCommandController, void>(
  ResidentVerificationCommandController.new,
);

class ResidentVerificationCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ResidentVerification?> approveVerification(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentVerificationRepositoryProvider).approve(id);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateVerification(result.value!.id, result.value!.userId);
    return result.value;
  }

  Future<ResidentVerification?> resetVerification(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentVerificationRepositoryProvider).reset(id);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateVerification(result.value!.id, result.value!.userId);
    return result.value;
  }

  Future<bool> deactivateResident({
    required String userId,
    required String reason,
    String? verificationId,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentVerificationRepositoryProvider).deactivateResident(
            userId: userId,
            reason: reason,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    if (verificationId != null) {
      ref.invalidate(residentVerificationDetailProvider(verificationId));
    }
    ref.invalidate(residentVerificationHistoryProvider(userId));
    ref.invalidate(residentVerificationListProvider);
    return true;
  }

  void _invalidateVerification(String verificationId, String userId) {
    ref.invalidate(residentVerificationDetailProvider(verificationId));
    ref.invalidate(residentVerificationHistoryProvider(userId));
    ref.invalidate(residentVerificationListProvider);
  }
}
