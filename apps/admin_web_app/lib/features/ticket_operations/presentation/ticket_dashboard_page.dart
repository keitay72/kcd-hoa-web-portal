import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/ticket.dart';
import 'ticket_providers.dart';

class TicketDashboardPage extends ConsumerWidget {
  const TicketDashboardPage({required this.queue, super.key});

  final TicketQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(ticketMetricsProvider);
    final tickets = ref.watch(ticketQueueProvider(queue));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(queue.label, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  _subtitleForQueue(queue),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/tickets'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('All Tickets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(ticketQueueProvider(queue)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        metrics.when(
          data: (value) => _MetricGrid(metrics: value),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Unable to load ticket metrics: $error'),
        ),
        const SizedBox(height: 20),
        tickets.when(
          data: (items) => _QueueTicketList(tickets: items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Unable to load queue: $error'),
        ),
      ],
    );
  }

  String _subtitleForQueue(TicketQueue queue) {
    return switch (queue) {
      TicketQueue.csr => 'New, open, and customer-facing tickets for CSR triage.',
      TicketQueue.dispatch => 'Route-impacting tickets ready for dispatch operations.',
      TicketQueue.urgent => 'Urgent and SLA-breached tickets needing immediate attention.',
      TicketQueue.aging => 'Open tickets older than 48 hours.',
      TicketQueue.all => 'Operational overview across all ticket queues.',
    };
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final TicketMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(label: 'Open', value: metrics.totalOpen.toString(), icon: Icons.pending_actions),
      _MetricCard(label: 'New', value: metrics.newTickets.toString(), icon: Icons.fiber_new),
      _MetricCard(label: 'Assigned', value: metrics.assigned.toString(), icon: Icons.assignment_ind),
      _MetricCard(label: 'In Progress', value: metrics.inProgress.toString(), icon: Icons.sync),
      _MetricCard(label: 'Urgent', value: metrics.urgent.toString(), icon: Icons.priority_high),
      _MetricCard(label: 'SLA Breached', value: metrics.slaBreached.toString(), icon: Icons.warning_amber),
      _MetricCard(label: 'Due Soon', value: metrics.slaDueSoon.toString(), icon: Icons.timer),
      _MetricCard(label: 'Resolved Today', value: metrics.resolvedToday.toString(), icon: Icons.check_circle_outline),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 1100
            ? (constraints.maxWidth - 48) / 4
            : constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTicketList extends StatelessWidget {
  const _QueueTicketList({required this.tickets});

  final List<ServiceTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No tickets in this queue.'),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return ListTile(
            leading: _SlaIcon(ticket: ticket),
            title: Text(ticket.subject),
            subtitle: Text('${ticket.hoaLabel} - ${ticket.type.label} - Age ${ticket.ageLabel}'),
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
}

class _SlaIcon extends StatelessWidget {
  const _SlaIcon({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    final color = switch (ticket.slaState) {
      SlaState.breached => Theme.of(context).colorScheme.error,
      SlaState.dueSoon => Colors.orange,
      SlaState.complete => Colors.green,
      SlaState.onTrack => Theme.of(context).colorScheme.primary,
    };

    return Tooltip(
      message: '${ticket.slaState.label}: ${ticket.slaLabel}',
      child: Icon(Icons.timer_outlined, color: color),
    );
  }
}
