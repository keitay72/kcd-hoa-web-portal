import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/customer_portal_home_repository.dart';
import '../domain/customer_portal_home.dart';

final customerPortalHomeRepositoryProvider =
    Provider<CustomerPortalHomeRepository>((ref) {
  return SupabaseCustomerPortalHomeRepository(
      ref.watch(supabaseClientProvider));
});

final customerPortalHomeProvider =
    FutureProvider.autoDispose<CustomerPortalHome>((ref) {
  return ref.watch(customerPortalHomeRepositoryProvider).loadHome();
});

final customerPortalTicketDetailProvider = FutureProvider.autoDispose
    .family<CustomerPortalTicketDetail, String>((ref, ticketId) {
  return ref
      .watch(customerPortalHomeRepositoryProvider)
      .loadTicketDetail(ticketId);
});
