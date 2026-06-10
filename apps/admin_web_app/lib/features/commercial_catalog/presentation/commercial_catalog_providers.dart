import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/commercial_catalog_repository.dart';
import '../domain/commercial_catalog_models.dart';

final commercialCatalogRepositoryProvider = Provider<CommercialCatalogRepository>((ref) {
  return SupabaseCommercialCatalogRepository(ref.watch(supabaseClientProvider));
});

final subscriptionPlansProvider = FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
  return ref.watch(commercialCatalogRepositoryProvider).listPlans();
});

final addonCatalogProvider = FutureProvider.autoDispose<List<AddonCatalogItem>>((ref) {
  return ref.watch(commercialCatalogRepositoryProvider).listAddons();
});

final commercialCatalogControllerProvider =
    AsyncNotifierProvider.autoDispose<CommercialCatalogController, void>(
  CommercialCatalogController.new,
);

class CommercialCatalogController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> savePlan({String? planId, required PlanInput input}) {
    return _run(() => ref.read(commercialCatalogRepositoryProvider).savePlan(
          planId: planId,
          input: input,
        ));
  }

  Future<bool> savePrice({
    required String planId,
    String? priceId,
    required PriceInput input,
  }) {
    return _run(() => ref.read(commercialCatalogRepositoryProvider).savePrice(
          planId: planId,
          priceId: priceId,
          input: input,
        ));
  }

  Future<bool> saveAddon({String? addonId, required AddonInput input}) {
    return _run(() => ref.read(commercialCatalogRepositoryProvider).saveAddon(
          addonId: addonId,
          input: input,
        ));
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }
    state = const AsyncData(null);
    ref.invalidate(subscriptionPlansProvider);
    ref.invalidate(addonCatalogProvider);
    return true;
  }
}
