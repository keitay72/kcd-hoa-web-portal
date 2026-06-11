import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/tenant_management_repository.dart';
import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';

final tenantManagementRepositoryProvider = Provider<TenantManagementRepository>((ref) {
  return SupabaseTenantManagementRepository(ref.watch(supabaseClientProvider));
});

final tenantListFiltersProvider = StateProvider.autoDispose<TenantListFilters>((ref) {
  return const TenantListFilters();
});

final tenantListProvider = FutureProvider.autoDispose<List<PlatformTenant>>((ref) {
  final filters = ref.watch(tenantListFiltersProvider);
  return ref.watch(tenantManagementRepositoryProvider).listTenants(filters);
});

final tenantDetailProvider = FutureProvider.autoDispose.family<TenantDetail, String>((ref, tenantId) {
  return ref.watch(tenantManagementRepositoryProvider).getTenantDetail(tenantId);
});

final tenantMutationControllerProvider =
    AsyncNotifierProvider.autoDispose<TenantMutationController, void>(
  TenantMutationController.new,
);

class TenantMutationController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<PlatformTenant?> createTenant(TenantInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantManagementRepositoryProvider).createTenant(input);
    });
    return _finish(result);
  }

  Future<PlatformTenant?> updateTenant({
    required String tenantId,
    required TenantInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantManagementRepositoryProvider).updateTenant(
            tenantId: tenantId,
            input: input,
          );
    });
    return _finish(result, tenantId: tenantId);
  }

  Future<bool> updateSettings({
    required String tenantId,
    required TenantSettingsInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).updateTenantSettings(
            tenantId: tenantId,
            input: input,
          ),
    );
  }

  Future<bool> updateEmailSettings({
    required String tenantId,
    required TenantEmailSettingsInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).updateEmailSettings(
            tenantId: tenantId,
            input: input,
          ),
    );
  }

  Future<bool> updateSmsSettings({
    required String tenantId,
    required TenantSmsSettingsInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).updateSmsSettings(
            tenantId: tenantId,
            input: input,
          ),
    );
  }

  Future<bool> saveBillingContact({
    required String tenantId,
    String? contactId,
    required TenantBillingContactInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).saveBillingContact(
            tenantId: tenantId,
            contactId: contactId,
            input: input,
          ),
    );
  }

  Future<bool> setAddonStatus({
    required String tenantId,
    required String addonId,
    required String status,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).setAddonStatus(
            tenantId: tenantId,
            addonId: addonId,
            status: status,
          ),
    );
  }

  Future<bool> saveSubscription({
    required String tenantId,
    String? subscriptionId,
    required TenantSubscriptionInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).saveSubscription(
            tenantId: tenantId,
            subscriptionId: subscriptionId,
            input: input,
          ),
    );
  }

  Future<StripeActionResult?> createCheckoutSession({
    required String tenantId,
    required String subscriptionId,
  }) {
    return _stripeAction(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).createCheckoutSession(
            tenantId: tenantId,
            subscriptionId: subscriptionId,
          ),
    );
  }

  Future<StripeActionResult?> syncStripeSubscription({
    required String tenantId,
    required String subscriptionId,
  }) {
    return _stripeAction(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).syncStripeSubscription(
            tenantId: tenantId,
            subscriptionId: subscriptionId,
          ),
    );
  }

  Future<bool> assignTenantStaff({
    required String tenantId,
    required TenantStaffAssignmentInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).assignTenantStaff(
            tenantId: tenantId,
            input: input,
          ),
    );
  }

  Future<bool> removeTenantStaff(TenantStaffAssignment assignment) {
    return _run(
      tenantId: assignment.tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).removeTenantStaff(assignment),
    );
  }

  Future<bool> saveOnboardingStatus({
    required String tenantId,
    required TenantOnboardingInput input,
  }) {
    return _run(
      tenantId: tenantId,
      action: () => ref.read(tenantManagementRepositoryProvider).saveOnboardingStatus(
            tenantId: tenantId,
            input: input,
          ),
    );
  }

  PlatformTenant? _finish(
    AsyncValue<PlatformTenant> result, {
    String? tenantId,
  }) {
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    ref.invalidate(tenantListProvider);
    if (tenantId != null) ref.invalidate(tenantDetailProvider(tenantId));
    return result.value;
  }

  Future<StripeActionResult?> _stripeAction({
    required String tenantId,
    required Future<StripeActionResult> Function() action,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    ref.invalidate(tenantDetailProvider(tenantId));
    return result.value;
  }

  Future<bool> _run({
    required String tenantId,
    required Future<void> Function() action,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    ref.invalidate(tenantListProvider);
    ref.invalidate(tenantDetailProvider(tenantId));
    return true;
  }
}
