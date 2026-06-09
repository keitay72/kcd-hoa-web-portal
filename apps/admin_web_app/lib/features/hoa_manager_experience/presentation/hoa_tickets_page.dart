import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ticket_operations/domain/ticket.dart';
import '../../ticket_operations/presentation/ticket_providers.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaTicketsPage extends ConsumerWidget {
  const HoaTicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeHoaScopeProvider);

    return scope.when(
      data: (item) {
        final hoaId = item?.hoaId;
        if (hoaId == null) return const Center(child: Text('No HOA scope assigned.'));
        final tickets = ref.watch(ticketListProvider(TicketListFilter(hoaId: hoaId)));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HoaScopeHeader(
                title: 'HOA Tickets',
                subtitle: 'Ticket visibility for your HOA community.',
              ),
              const SizedBox(height: 20),
              Expanded(
                child: tickets.when(
                  data: (items) => _TicketList(tickets: items),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Unable to load tickets: $error')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Unable to load HOA scope: $error')),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets});

  final List<ServiceTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return const Center(child: Text('No tickets found.'));

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return ListTile(
            leading: Icon(
              Icons.confirmation_number_outlined,
              color: _slaColor(context, ticket),
            ),
            title: Text(ticket.subject),
            subtitle: Text('${ticket.requesterLabel} - ${ticket.addressLabel}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(ticket.priority.label)),
                Chip(label: Text(ticket.status.label)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/tickets/${ticket.id}'),
          );
        },
      ),
    );
  }

  Color _slaColor(BuildContext context, ServiceTicket ticket) {
    return switch (ticket.slaState) {
      SlaState.breached => Theme.of(context).colorScheme.error,
      SlaState.dueSoon => Colors.orange,
      SlaState.complete => Colors.green,
      SlaState.onTrack => Theme.of(context).colorScheme.primary,
    };
  }
}
