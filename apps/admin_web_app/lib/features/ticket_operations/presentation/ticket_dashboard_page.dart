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
                Text(
                  queue.label,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
      TicketQueue.csr =>
        'New, open, and customer-facing tickets for CSR triage.',
      TicketQueue.dispatch =>
        'Route-impacting tickets ready for dispatch operations.',
      TicketQueue.urgent =>
        'Urgent and SLA-breached tickets needing immediate attention.',
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
      _MetricCard(
        label: 'Open',
        value: metrics.totalOpen.toString(),
        icon: Icons.pending_actions,
      ),
      _MetricCard(
        label: 'New',
        value: metrics.newTickets.toString(),
        icon: Icons.fiber_new,
      ),
      _MetricCard(
        label: 'Assigned',
        value: metrics.assigned.toString(),
        icon: Icons.assignment_ind,
      ),
      _MetricCard(
        label: 'In Progress',
        value: metrics.inProgress.toString(),
        icon: Icons.sync,
      ),
      _MetricCard(
        label: 'Urgent',
        value: metrics.urgent.toString(),
        icon: Icons.priority_high,
      ),
      _MetricCard(
        label: 'SLA Breached',
        value: metrics.slaBreached.toString(),
        icon: Icons.warning_amber,
      ),
      _MetricCard(
        label: 'Due Soon',
        value: metrics.slaDueSoon.toString(),
        icon: Icons.timer,
      ),
      _MetricCard(
        label: 'Resolved Today',
        value: metrics.resolvedToday.toString(),
        icon: Icons.check_circle_outline,
      ),
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
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        return Column(
          children: [
            for (var index = 0; index < tickets.length; index += 1) ...[
              _QueueTicketCard(
                ticket: tickets[index],
                isCompact: isCompact,
              ),
              if (index != tickets.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _QueueTicketCard extends StatelessWidget {
  const _QueueTicketCard({
    required this.ticket,
    required this.isCompact,
  });

  final ServiceTicket ticket;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final slaColor = _slaColor(context, ticket);
    final statusStyle = _statusStyle(context, ticket.status);
    final priorityStyle = _priorityStyle(context, ticket.priority);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/admin/tickets/${ticket.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TicketTitleBlock(ticket: ticket),
                    const SizedBox(height: 14),
                    _TicketMetaGrid(ticket: ticket),
                    const SizedBox(height: 14),
                    _TicketActionStrip(
                      ticket: ticket,
                      slaColor: slaColor,
                      statusStyle: statusStyle,
                      priorityStyle: priorityStyle,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 112,
                      decoration: BoxDecoration(
                        color: slaColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TicketTitleBlock(ticket: ticket),
                          const SizedBox(height: 14),
                          _TicketMetaGrid(ticket: ticket),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 330,
                      child: _TicketActionStrip(
                        ticket: ticket,
                        slaColor: slaColor,
                        statusStyle: statusStyle,
                        priorityStyle: priorityStyle,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TicketTitleBlock extends StatelessWidget {
  const _TicketTitleBlock({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              ticket.subject,
              style: theme.textTheme.titleLarge,
            ),
            _SoftBadge(
              label: ticket.type.label,
              icon: Icons.category_outlined,
              foreground: theme.colorScheme.primary,
              background: theme.colorScheme.primaryContainer.withOpacity(0.45),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ticket ${ticket.id.substring(0, 8)} · Created ${ticket.ageLabel} ago',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TicketMetaGrid extends StatelessWidget {
  const _TicketMetaGrid({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        _MetaItem(
          icon: Icons.person_outline,
          label: 'Customer',
          value: ticket.requesterLabel,
        ),
        _MetaItem(
          icon: Icons.location_on_outlined,
          label: 'Service Address',
          value: ticket.addressLabel,
        ),
        _MetaItem(
          icon: Icons.domain_outlined,
          label: 'Community',
          value: ticket.hoaLabel,
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketActionStrip extends StatelessWidget {
  const _TicketActionStrip({
    required this.ticket,
    required this.slaColor,
    required this.statusStyle,
    required this.priorityStyle,
  });

  final ServiceTicket ticket;
  final Color slaColor;
  final _BadgeStyle statusStyle;
  final _BadgeStyle priorityStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _SoftBadge(
              label: ticket.status.label,
              icon: Icons.circle,
              foreground: statusStyle.foreground,
              background: statusStyle.background,
              dotIcon: true,
            ),
            _SoftBadge(
              label: ticket.priority.label,
              icon: Icons.flag_outlined,
              foreground: priorityStyle.foreground,
              background: priorityStyle.background,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SlaLine(ticket: ticket, color: slaColor),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => context.go('/admin/tickets/${ticket.id}'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Ticket'),
          ),
        ),
      ],
    );
  }
}

class _SlaLine extends StatelessWidget {
  const _SlaLine({required this.ticket, required this.color});

  final ServiceTicket ticket;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${ticket.slaState.label}: ${ticket.slaLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    this.dotIcon = false,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final bool dotIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dotIcon ? 9 : 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}

Color _slaColor(BuildContext context, ServiceTicket ticket) {
  return switch (ticket.slaState) {
    SlaState.breached => Theme.of(context).colorScheme.error,
    SlaState.dueSoon => Colors.orange,
    SlaState.complete => Colors.green,
    SlaState.onTrack => Theme.of(context).colorScheme.primary,
  };
}

_BadgeStyle _statusStyle(BuildContext context, TicketStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    TicketStatus.newTicket => _BadgeStyle(
        foreground: Colors.blue.shade800,
        background: Colors.blue.shade50,
      ),
    TicketStatus.open => _BadgeStyle(
        foreground: scheme.primary,
        background: scheme.primaryContainer.withOpacity(0.45),
      ),
    TicketStatus.assigned => _BadgeStyle(
        foreground: Colors.indigo.shade800,
        background: Colors.indigo.shade50,
      ),
    TicketStatus.inProgress => _BadgeStyle(
        foreground: Colors.orange.shade900,
        background: Colors.orange.shade50,
      ),
    TicketStatus.waitingOnCustomer => _BadgeStyle(
        foreground: Colors.purple.shade800,
        background: Colors.purple.shade50,
      ),
    TicketStatus.resolved => _BadgeStyle(
        foreground: Colors.green.shade800,
        background: Colors.green.shade50,
      ),
    TicketStatus.closed => _BadgeStyle(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
      ),
  };
}

_BadgeStyle _priorityStyle(BuildContext context, TicketPriority priority) {
  final scheme = Theme.of(context).colorScheme;
  return switch (priority) {
    TicketPriority.low => _BadgeStyle(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
      ),
    TicketPriority.normal => _BadgeStyle(
        foreground: scheme.primary,
        background: scheme.primaryContainer.withOpacity(0.42),
      ),
    TicketPriority.high => _BadgeStyle(
        foreground: Colors.deepOrange.shade900,
        background: Colors.deepOrange.shade50,
      ),
    TicketPriority.urgent => _BadgeStyle(
        foreground: scheme.error,
        background: scheme.errorContainer.withOpacity(0.55),
      ),
  };
}
