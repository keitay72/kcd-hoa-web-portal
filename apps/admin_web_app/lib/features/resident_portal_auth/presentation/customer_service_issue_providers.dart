import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/customer_service_issue_repository.dart';

final customerServiceIssueRepositoryProvider =
    Provider<CustomerServiceIssueRepository>((ref) {
  return SupabaseCustomerServiceIssueRepository(
    ref.watch(supabaseClientProvider),
  );
});

final customerServiceIssueControllerProvider =
    AsyncNotifierProvider.autoDispose<CustomerServiceIssueController, void>(
  CustomerServiceIssueController.new,
);

class CustomerServiceIssueController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> submit(CustomerServiceIssueInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(customerServiceIssueRepositoryProvider).submit(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    return result.value;
  }
}
