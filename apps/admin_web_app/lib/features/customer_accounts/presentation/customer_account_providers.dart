import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/customer_account_repository.dart';
import '../domain/customer_account.dart';
import '../domain/customer_account_input.dart';
import '../domain/service_location.dart';
import '../domain/service_location_input.dart';

final customerAccountRepositoryProvider =
    Provider<CustomerAccountRepository>((ref) {
  return SupabaseCustomerAccountRepository(ref.watch(supabaseClientProvider));
});

final customerAccountListProvider = FutureProvider.autoDispose
    .family<List<CustomerAccount>, CustomerAccountListFilter>(
  (ref, filter) {
    return ref.watch(customerAccountRepositoryProvider).listAccounts(
          tenantId: filter.tenantId,
          accountType: filter.accountType,
        );
  },
);

final serviceLocationListProvider = FutureProvider.autoDispose
    .family<List<ServiceLocation>, ServiceLocationListFilter>(
  (ref, filter) {
    return ref.watch(customerAccountRepositoryProvider).listServiceLocations(
          customerAccountId: filter.customerAccountId,
          tenantId: filter.tenantId,
        );
  },
);

final customerAccountFormControllerProvider =
    AsyncNotifierProvider.autoDispose<CustomerAccountFormController, void>(
  CustomerAccountFormController.new,
);

final serviceLocationFormControllerProvider =
    AsyncNotifierProvider.autoDispose<ServiceLocationFormController, void>(
  ServiceLocationFormController.new,
);

class CustomerAccountListFilter {
  const CustomerAccountListFilter({
    this.tenantId,
    this.accountType,
  });

  final String? tenantId;
  final CustomerAccountType? accountType;

  @override
  bool operator ==(Object other) {
    return other is CustomerAccountListFilter &&
        other.tenantId == tenantId &&
        other.accountType == accountType;
  }

  @override
  int get hashCode => Object.hash(tenantId, accountType);
}

class ServiceLocationListFilter {
  const ServiceLocationListFilter({
    this.tenantId,
    this.customerAccountId,
  });

  final String? tenantId;
  final String? customerAccountId;

  @override
  bool operator ==(Object other) {
    return other is ServiceLocationListFilter &&
        other.tenantId == tenantId &&
        other.customerAccountId == customerAccountId;
  }

  @override
  int get hashCode => Object.hash(tenantId, customerAccountId);
}

class CustomerAccountFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<CustomerAccount?> create(
    CustomerAccountInput input, {
    String? tenantId,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(customerAccountRepositoryProvider)
          .createAccount(input, tenantId: tenantId);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAccountLists();
    return result.value;
  }

  Future<CustomerAccount?> updateAccount({
    required String id,
    required CustomerAccountInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(customerAccountRepositoryProvider)
          .updateAccount(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAccountLists();
    return result.value;
  }

  void _invalidateAccountLists() {
    ref.invalidate(customerAccountListProvider);
    ref.invalidate(serviceLocationListProvider);
  }
}

class ServiceLocationFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ServiceLocation?> create(
    ServiceLocationInput input, {
    String? tenantId,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(customerAccountRepositoryProvider)
          .createServiceLocation(input, tenantId: tenantId);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateLocationLists();
    return result.value;
  }

  Future<ServiceLocation?> updateServiceLocation({
    required String id,
    required ServiceLocationInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(customerAccountRepositoryProvider)
          .updateServiceLocation(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateLocationLists();
    return result.value;
  }

  void _invalidateLocationLists() {
    ref.invalidate(serviceLocationListProvider);
  }
}
