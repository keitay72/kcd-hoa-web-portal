import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../address_registry/domain/hoa_address.dart';
import '../data/ticket_repository.dart';
import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';

export '../data/ticket_repository.dart' show TicketListFilter;

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return SupabaseTicketRepository(ref.watch(supabaseClientProvider));
});

final residentTicketAddressesProvider =
    FutureProvider.autoDispose<List<HoaAddress>>((ref) {
  return ref.watch(ticketRepositoryProvider).currentResidentAddresses();
});

final ticketListProvider = FutureProvider.autoDispose
    .family<List<ServiceTicket>, TicketListFilter>((ref, filter) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(ticketRepositoryProvider).list(filter);
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final ticketQueueProvider = FutureProvider.autoDispose
    .family<List<ServiceTicket>, TicketQueue>((ref, queue) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(ticketRepositoryProvider).queue(queue);
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final ticketMetricsProvider =
    FutureProvider.autoDispose<TicketMetrics>((ref) async {
  final tickets =
      await ref.watch(ticketListProvider(const TicketListFilter()).future);
  return TicketMetrics.fromTickets(tickets);
});

final ticketDetailProvider =
    FutureProvider.autoDispose.family<ServiceTicket, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(ticketRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.hoaId)) {
    throw StateError('Ticket is outside the active view.');
  }
  return item;
});

final ticketEventsProvider = FutureProvider.autoDispose
    .family<List<TicketEvent>, String>((ref, ticketId) {
  return ref.watch(ticketRepositoryProvider).eventsForTicket(ticketId);
});

final ticketAttachmentsProvider = FutureProvider.autoDispose
    .family<List<TicketAttachment>, String>((ref, ticketId) {
  return ref.watch(ticketRepositoryProvider).attachmentsForTicket(ticketId);
});

final ticketAssigneeOptionsProvider =
    FutureProvider.autoDispose<List<TicketAssigneeOption>>((ref) {
  return ref.watch(ticketRepositoryProvider).assigneeOptions();
});

final ticketCommandProvider =
    AsyncNotifierProvider.autoDispose<TicketCommandController, void>(
  TicketCommandController.new,
);

class TicketCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ServiceTicket?> updateStatus(TicketStatusUpdateInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).updateStatus(input);
    });

    return _finishTicketCommand(result, input.ticket.id);
  }

  Future<ServiceTicket?> createResidentTicket(
    ResidentTicketCreateInput input,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).createResidentTicket(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    final ticket = result.value!;
    state = const AsyncData(null);
    _invalidateTicketViews(ticket.id);
    ref.invalidate(residentTicketAddressesProvider);
    return ticket;
  }

  Future<ServiceTicket?> assignTicket(TicketAssignmentInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).assignTicket(input);
    });

    return _finishTicketCommand(result, input.ticket.id);
  }

  Future<ServiceTicket?> updatePriority(TicketPriorityUpdateInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).updatePriority(input);
    });

    return _finishTicketCommand(result, input.ticket.id);
  }

  Future<bool> addInternalNote(TicketInternalNoteInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).addInternalNote(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    _invalidateTicketViews(input.ticket.id);
    return true;
  }

  Future<bool> addCustomerUpdate(TicketCustomerUpdateInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).addCustomerUpdate(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return false;
    }

    state = const AsyncData(null);
    _invalidateTicketViews(input.ticket.id);
    return true;
  }

  Future<ServiceTicket?> runWorkflowAutomation(ServiceTicket ticket) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(ticketRepositoryProvider).runWorkflowAutomation(ticket);
    });

    return _finishTicketCommand(result, ticket.id);
  }

  ServiceTicket? _finishTicketCommand(
    AsyncValue<ServiceTicket> result,
    String ticketId,
  ) {
    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateTicketViews(ticketId);
    return result.value;
  }

  void _invalidateTicketViews(String ticketId) {
    ref.invalidate(ticketListProvider);
    ref.invalidate(ticketQueueProvider);
    ref.invalidate(ticketMetricsProvider);
    ref.invalidate(ticketDetailProvider(ticketId));
    ref.invalidate(ticketEventsProvider(ticketId));
    ref.invalidate(ticketAttachmentsProvider(ticketId));
  }
}
