import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../data/resident_auth_repository.dart';
import '../domain/resident_address.dart';
import '../domain/resident_registration.dart';

final residentAuthRepositoryProvider = Provider<ResidentAuthRepository>((ref) {
  return SupabaseResidentAuthRepository(ref.watch(supabaseClientProvider));
});

final residentRegistrationStateProvider =
    StateProvider<ResidentRegistrationResult?>((ref) => null);

final verifiedAddressProvider = StateProvider<VerifiedResidentAddress?>((ref) {
  return ref.watch(residentRegistrationStateProvider)?.address;
});

final residentAuthControllerProvider =
    AsyncNotifierProvider.autoDispose<ResidentAuthController, void>(
  ResidentAuthController.new,
);

class ResidentAuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentAuthRepositoryProvider).signIn(
            email: email,
            password: password,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    return true;
  }

  Future<VerifiedResidentAddress?> verifyAddress(ResidentAddressInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentAuthRepositoryProvider).verifyAddress(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    ref.read(verifiedAddressProvider.notifier).state = result.value;
    state = const AsyncData(null);
    return result.value;
  }

  Future<ResidentRegistrationResult?> register(ResidentRegistrationInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentAuthRepositoryProvider).register(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    ref.read(residentRegistrationStateProvider.notifier).state = result.value;
    ref.read(verifiedAddressProvider.notifier).state = result.value?.address;
    state = const AsyncData(null);
    return result.value;
  }

  Future<bool> verifyActivationCode(String code) async {
    final registration = ref.read(residentRegistrationStateProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      if (registration == null) {
        return ref
            .read(residentAuthRepositoryProvider)
            .verifyActivationCodeForCurrentUser(code);
      }

      return ref.read(residentAuthRepositoryProvider).verifyActivationCode(
            verificationId: registration.verificationId,
            addressId: registration.address.id,
            code: code,
          );
    });

    if (result.hasError || result.value != true) {
      state = AsyncError<void>(
        result.error ?? StateError('Activation code verification failed.'),
        result.stackTrace ?? StackTrace.current,
      );
      return false;
    }

    state = const AsyncData(null);
    return true;
  }
}
