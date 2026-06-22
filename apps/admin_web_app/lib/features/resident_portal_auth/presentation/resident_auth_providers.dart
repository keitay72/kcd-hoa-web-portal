import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/resident_auth_repository.dart';
import '../domain/resident_address.dart';
import '../domain/resident_registration.dart';

final residentPortalAuthRepositoryProvider =
    Provider<ResidentPortalAuthRepository>((ref) {
  return SupabaseResidentPortalAuthRepository(
      ref.watch(supabaseClientProvider));
});

final residentRegistrationStateProvider =
    StateProvider<ResidentRegistrationResult?>((ref) => null);

final verifiedResidentAddressProvider =
    StateProvider<VerifiedResidentAddress?>((ref) {
  return ref.watch(residentRegistrationStateProvider)?.address;
});

final residentPortalAuthControllerProvider =
    AsyncNotifierProvider.autoDispose<ResidentPortalAuthController, void>(
  ResidentPortalAuthController.new,
);

class ResidentPortalAuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentPortalAuthRepositoryProvider).signIn(
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

  Future<bool> sendPasswordResetEmail({
    required String tenantCode,
    required String email,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(residentPortalAuthRepositoryProvider)
          .sendPasswordResetEmail(
            tenantCode: tenantCode,
            email: email,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    return true;
  }

  Future<bool> resendVerificationEmail({
    required String tenantCode,
    required String email,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(residentPortalAuthRepositoryProvider)
          .resendVerificationEmail(
            tenantCode: tenantCode,
            email: email,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    return true;
  }

  Future<bool> beginPasswordRecovery(Uri uri) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(residentPortalAuthRepositoryProvider)
          .beginPasswordRecoveryFromUri(uri);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    return true;
  }

  Future<bool> updatePassword(
    String password, {
    String? fullName,
    String? phone,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentPortalAuthRepositoryProvider).updatePassword(
            password,
            fullName: fullName,
            phone: phone,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    return true;
  }

  Future<VerifiedResidentAddress?> verifyAddress({
    required String tenantCode,
    required ResidentAddressInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentPortalAuthRepositoryProvider).verifyAddress(
            tenantCode: tenantCode,
            input: input,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    ref.read(verifiedResidentAddressProvider.notifier).state = result.value;
    state = const AsyncData(null);
    return result.value;
  }

  Future<ResidentRegistrationResult?> register({
    required String tenantCode,
    required ResidentRegistrationInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(residentPortalAuthRepositoryProvider).register(
            tenantCode: tenantCode,
            input: input,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    ref.read(residentRegistrationStateProvider.notifier).state = result.value;
    ref.read(verifiedResidentAddressProvider.notifier).state =
        result.value?.address;
    state = const AsyncData(null);
    return result.value;
  }

  Future<bool> verifyActivationCode(String code) async {
    final registration = ref.read(residentRegistrationStateProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      if (registration == null) {
        return ref
            .read(residentPortalAuthRepositoryProvider)
            .verifyActivationCodeForCurrentUser(code);
      }

      return ref
          .read(residentPortalAuthRepositoryProvider)
          .verifyActivationCode(
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
