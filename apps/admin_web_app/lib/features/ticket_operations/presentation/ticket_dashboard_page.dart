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
                IconButton.filledTonal(
                  tooltip: 'Refresh queue',
                  onPressed: () {
                    ref.invalidate(ticketQueueProvider(queue));
                    ref.invalidate(ticketMetricsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        metrics.when(
          data: (value) => _QueueSummaryStrip(
            queue: queue,
            metrics: value,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Unable to load ticket metrics: $error'),
        ),
        const SizedBox(height: 20),
        tickets.when(
          data: (items) => _QueueTicketList(
            queue: queue,
            tickets: items,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Unable to load queue: $error'),
        ),
      ],
    );
  }

  String _subtitleForQueue(TicketQueue queue) {
    return switch (queue) {
      TicketQueue.csr =>
        'Triage customer issues, capture updates, and keep SLA risk visible.',
      TicketQueue.urgent =>
        'Urgent and SLA-breached tickets needing immediate attention.',
      TicketQueue.aging => 'Open tickets older than 48 hours.',
      TicketQueue.all => 'Operational overview across all ticket queues.',
    };
  }
}

class _QueueSummaryStrip extends StatelessWidget {
  const _QueueSummaryStrip({
    required this.queue,
    required this.metrics,
  });

  final TicketQueue queue;
  final TicketMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = _cardsForQueue();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (card) => _QueueSummaryChip(
              label: card.label,
              value: card.value,
              icon: card.icon,
              tone: card.tone(context),
            ),
          )
          .toList(),
    );
  }

  List<_QueueSummaryData> _cardsForQueue() {
    return switch (queue) {
      TicketQueue.csr => [
          _QueueSummaryData(
            label: 'New',
            value: metrics.newTickets,
            icon: Icons.fiber_new,
            tone: (context) => Colors.blue.shade700,
          ),
          _QueueSummaryData(
            label: 'Open',
            value: metrics.totalOpen,
            icon: Icons.pending_actions,
            tone: (context) => Theme.of(context).colorScheme.primary,
          ),
          _QueueSummaryData(
            label: 'Assigned',
            value: metrics.assigned,
            icon: Icons.assignment_ind,
            tone: (context) => Colors.indigo.shade700,
          ),
          _QueueSummaryData(
            label: 'Due Soon',
            value: metrics.slaDueSoon,
            icon: Icons.timer_outlined,
            tone: (context) => Colors.orange.shade800,
          ),
        ],
      TicketQueue.urgent => [
          _QueueSummaryData(
            label: 'Urgent',
            value: metrics.urgent,
            icon: Icons.priority_high,
            tone: (context) => Theme.of(context).colorScheme.error,
          ),
          _QueueSummaryData(
            label: 'SLA Breached',
            value: metrics.slaBreached,
            icon: Icons.warning_amber,
            tone: (context) => Theme.of(context).colorScheme.error,
          ),
          _QueueSummaryData(
            label: 'Due Soon',
            value: metrics.slaDueSoon,
            icon: Icons.timer_outlined,
            tone: (context) => Colors.orange.shade800,
          ),
          _QueueSummaryData(
            label: 'Open',
            value: metrics.totalOpen,
            icon: Icons.pending_actions,
            tone: (context) => Theme.of(context).colorScheme.primary,
          ),
        ],
      TicketQueue.aging => [
          _QueueSummaryData(
            label: 'Open',
            value: metrics.totalOpen,
            icon: Icons.pending_actions,
            tone: (context) => Theme.of(context).colorScheme.primary,
          ),
          _QueueSummaryData(
            label: 'In Progress',
            value: metrics.inProgress,
            icon: Icons.sync,
            tone: (context) => Colors.orange.shade800,
          ),
          _QueueSummaryData(
            label: 'Due Soon',
            value: metrics.slaDueSoon,
            icon: Icons.timer_outlined,
            tone: (context) => Colors.orange.shade800,
          ),
          _QueueSummaryData(
            label: 'SLA Breached',
            value: metrics.slaBreached,
            icon: Icons.warning_amber,
            tone: (context) => Theme.of(context).colorScheme.error,
          ),
        ],
      TicketQueue.all => [
          _QueueSummaryData(
            label: 'Open',
            value: metrics.totalOpen,
            icon: Icons.pending_actions,
            tone: (context) => Theme.of(context).colorScheme.primary,
          ),
          _QueueSummaryData(
            label: 'New',
            value: metrics.newTickets,
            icon: Icons.fiber_new,
            tone: (context) => Colors.blue.shade700,
          ),
          _QueueSummaryData(
            label: 'Assigned',
            value: metrics.assigned,
            icon: Icons.assignment_ind,
            tone: (context) => Colors.indigo.shade700,
          ),
          _QueueSummaryData(
            label: 'Resolved Today',
            value: metrics.resolvedToday,
            icon: Icons.check_circle_outline,
            tone: (context) => Colors.green.shade800,
          ),
        ],
    };
  }
}

class _QueueSummaryData {
  const _QueueSummaryData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color Function(BuildContext context) tone;
}

class _QueueSummaryChip extends StatelessWidget {
  const _QueueSummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          _CountPill(
            value: value,
            foreground: tone,
            background: Theme.of(context).colorScheme.surface,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _QueueTicketList extends StatelessWidget {
  const _QueueTicketList({
    required this.queue,
    required this.tickets,
  });

  final TicketQueue queue;
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
        return _TicketBoard(
          queue: queue,
          tickets: tickets,
          compact: constraints.maxWidth < 860,
        );
      },
    );
  }
}

class _TicketBoard extends StatelessWidget {
  const _TicketBoard({
    required this.queue,
    required this.tickets,
    required this.compact,
  });

  final TicketQueue queue;
  final List<ServiceTicket> tickets;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final grouped = {
      for (final status in _statusOrderForQueue(queue))
        status: tickets.where((ticket) => ticket.status == status).toList(),
    };
    final visibleStatuses = _statusOrderForQueue(queue)
        .where((status) => grouped[status]!.isNotEmpty || !compact)
        .toList();

    if (compact) {
      return Column(
        children: [
          for (var index = 0; index < visibleStatuses.length; index += 1) ...[
            _TicketBoardColumn(
              status: visibleStatuses[index],
              tickets: grouped[visibleStatuses[index]]!,
              compact: true,
            ),
            if (index != visibleStatuses.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final boardHeight = (viewportHeight * 0.66).clamp(480.0, 760.0);

    return Container(
      height: boardHeight,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.28),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < visibleStatuses.length; index += 1)
                Padding(
                  padding: EdgeInsets.only(
                    right: index == visibleStatuses.length - 1 ? 0 : 16,
                  ),
                  child: SizedBox(
                    width: 292,
                    height: boardHeight - 32,
                    child: _TicketBoardColumn(
                      status: visibleStatuses[index],
                      tickets: grouped[visibleStatuses[index]]!,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketBoardColumn extends StatelessWidget {
  const _TicketBoardColumn({
    required this.status,
    required this.tickets,
    this.compact = false,
  });

  final TicketStatus status;
  final List<ServiceTicket> tickets;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(context, status);

    return Container(
      decoration: BoxDecoration(
        color: style.background.withOpacity(0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.foreground.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                _CountPill(
                  value: tickets.length,
                  foreground: style.foreground,
                  background: Theme.of(context).colorScheme.surface,
                ),
              ],
            ),
          ),
          Container(height: 3, color: style.foreground),
          if (tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No tickets',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else if (compact)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (var index = 0; index < tickets.length; index += 1) ...[
                    _BoardTicketCard(ticket: tickets[index]),
                    if (index != tickets.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _BoardTicketCard(ticket: tickets[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardTicketCard extends StatelessWidget {
  const _BoardTicketCard({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityStyle = _priorityStyle(context, ticket.priority);
    final slaColor = _slaColor(context, ticket);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(_ticketDetailPath(context, ticket.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '#${ticket.id.substring(0, 8)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    ticket.ageLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket.subject,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SoftBadge(
                    label: ticket.priority.label,
                    icon: Icons.flag_outlined,
                    foreground: priorityStyle.foreground,
                    background: priorityStyle.background,
                  ),
                  _SoftBadge(
                    label: ticket.type.label,
                    icon: Icons.category_outlined,
                    foreground: theme.colorScheme.primary,
                    background:
                        theme.colorScheme.primaryContainer.withOpacity(0.45),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MiniInfoLine(
                icon: Icons.person_outline,
                text: ticket.requesterLabel,
              ),
              const SizedBox(height: 5),
              _MiniInfoLine(
                icon: Icons.location_on_outlined,
                text: ticket.addressLabel,
              ),
              const SizedBox(height: 5),
              _MiniInfoLine(
                icon: Icons.timer_outlined,
                text: ticket.slaLabel,
                color: slaColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfoLine extends StatelessWidget {
  const _MiniInfoLine({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                ),
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.value,
    required this.foreground,
    required this.background,
  });

  final int value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.2)),
      ),
      child: Text(
        value.toString(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

String _ticketDetailPath(BuildContext context, String ticketId) {
  final currentPath = GoRouterState.of(context).uri.path;
  final source = switch (currentPath) {
    '/admin/tickets/csr' => 'csr',
    '/admin/tickets/urgent' => 'urgent',
    '/admin/tickets/aging' => 'aging',
    _ => null,
  };

  if (source == null) return '/admin/tickets/$ticketId';

  return Uri(
    path: '/admin/tickets/$ticketId',
    queryParameters: {'from': source},
  ).toString();
}

List<TicketStatus> _statusOrderForQueue(TicketQueue queue) {
  return switch (queue) {
    TicketQueue.csr => const [
        TicketStatus.newTicket,
        TicketStatus.open,
        TicketStatus.assigned,
        TicketStatus.inProgress,
        TicketStatus.waitingOnCustomer,
      ],
    TicketQueue.urgent || TicketQueue.aging || TicketQueue.all => const [
        TicketStatus.newTicket,
        TicketStatus.open,
        TicketStatus.assigned,
        TicketStatus.inProgress,
        TicketStatus.waitingOnCustomer,
        TicketStatus.resolved,
        TicketStatus.closed,
      ],
  };
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

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
          Icon(icon, size: 16, color: foreground),
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
